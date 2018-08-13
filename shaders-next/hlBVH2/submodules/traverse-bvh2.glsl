
// default definitions

#ifndef _CACHE_BINDING
#define _CACHE_BINDING 9
#endif

#ifndef _RAY_TYPE
#define _RAY_TYPE VtRay
#endif


const int localStackSize = 8, pageCount = 4, computedStackSize = localStackSize*pageCount, max_iteraction = 8192;
layout ( std430, binding = _CACHE_BINDING, set = 0 ) coherent buffer VT_PAGE_SYSTEM { int pages[][8]; };


struct BvhTraverseState {
    int idx, defTriangleID, stackPtr, cacheID, pageID; lowp bvec4_ boxSide; float minDist;
    fvec4_ minusOrig, directInv;
} traverseState;

struct PrimitiveState {
    vec4 lastIntersection;
    vec4 orig;
#ifdef VRT_USE_FAST_INTERSECTION
    vec4 dir;
#else
    int axis; mat3 iM;
#endif
} primitiveState;


shared int localStack[WORK_SIZE][localStackSize];
#define lstack localStack[Local_Idx]

int loadStack() {
    if (traverseState.stackPtr <= 0 && traverseState.pageID > 0) { 
        lstack = pages[traverseState.cacheID*pageCount + (--traverseState.pageID)]; traverseState.stackPtr = localStackSize; 
    };
    int idx = --traverseState.stackPtr, rsl = lstack[idx]; return rsl;
}

void storeStack(in int rsl) {
    if (traverseState.stackPtr >= localStackSize && traverseState.pageID < pageCount) {
        pages[traverseState.cacheID*pageCount + (traverseState.pageID++)] = lstack; traverseState.stackPtr = 0;
    }
    int idx = traverseState.stackPtr++; lstack[idx] = rsl;
}

bool stackIsFull() { return traverseState.stackPtr >= localStackSize && traverseState.pageID >= pageCount; }
bool stackIsEmpty() { return traverseState.stackPtr <= 0 && traverseState.pageID <= 0; }
void doIntersection() {
    const bool isvalid = true; //traverseState.defTriangleID >= 0;
    vec2 uv = vec2(0.f.xx); const float d = 
#ifdef VRT_USE_FAST_INTERSECTION
        intersectTriangle(primitiveState.orig, primitiveState.dir, traverseState.defTriangleID, uv.xy, isvalid);
#else
        intersectTriangle(primitiveState.orig, primitiveState.iM, primitiveState.axis, traverseState.defTriangleID, uv.xy, isvalid);
#endif
#define nearhit primitiveState.lastIntersection.z

    [[flatten]]
    if (d < INFINITY && d <= nearhit && d >= traverseState.minDist.x) {
        primitiveState.lastIntersection = vec4(uv.xy, d.x, intBitsToFloat(traverseState.defTriangleID+1)); 
    } traverseState.defTriangleID=-1;
}

void traverseBvh2(in bool valid, in int eht, in vec3 orig, in vec2 pdir) {

    // test constants
    const vec4 
        torig = -divW(mult4( bvhBlock.transform, vec4(orig, 1.0f))),
        torigTo = divW(mult4( bvhBlock.transform, vec4(orig, 1.0f) + vec4(dcts(pdir.xy), 0.f))),
        tdir = torigTo+torig;

    // make vector for box and triangle intersection
    const float dirlen = length(tdir);
    const vec4 direct = tdir / dirlen;
    const vec4 dirproj = 1.f / (max(abs(direct), 1e-4f)*sign(direct));

    // limitation of distance
    const lowp bvec3_ bsgn = (bvec3_(sign(dirproj.xyz)*ftype_(1.0001f))+true_)>>true_;

    // initial state
    traverseState.defTriangleID = -1;

#ifdef VRT_USE_FAST_INTERSECTION
    primitiveState.dir = direct;
#else
    // calculate longest axis
    primitiveState.axis = 2;
    {
        vec3 drs = abs(direct); 
        if (drs.y >= drs.x && drs.y > drs.z) primitiveState.axis = 1;
        if (drs.x >= drs.z && drs.x > drs.y) primitiveState.axis = 0;
        if (drs.z >= drs.y && drs.z > drs.x) primitiveState.axis = 2;
    }

    // calculate affine matrices
    vec4 vm = vec4(-direct, 1.f) / (primitiveState.axis == 0 ? direct.x : (primitiveState.axis == 1 ? direct.y : direct.z));
    primitiveState.iM = transpose(mat3(
        primitiveState.axis == 0 ? vm.wyz : vec3(1.f,0.f,0.f),
        primitiveState.axis == 1 ? vm.xwz : vec3(0.f,1.f,0.f),
        primitiveState.axis == 2 ? vm.xyw : vec3(0.f,0.f,1.f)
    ));
#endif

    // test intersection with main box
    vec2 nears = (-INFINITY).xx, fars = INFINITY.xx;
    const vec2 bndsf2 = vec2(-1.0005f, 1.0005f);
    const int entry = (valid ? BVH_ENTRY : -1), _cmp = entry >> 1;
    traverseState.idx = SSC(intersectCubeF32Single((torig*dirproj).xyz, dirproj.xyz, bsgn, mat3x2(bndsf2,bndsf2,bndsf2), nears.x, fars.x)) ? entry : -1; 
    traverseState.stackPtr = 0, traverseState.pageID = 0;

    const float diffOffset = -max(nears.x, 0.f);
    primitiveState.orig = fma(direct, diffOffset.xxxx, torig);
    primitiveState.lastIntersection = eht >= 0 ? hits[eht].uvt : vec4(0.f.xx, INFINITY, FINT_ZERO), primitiveState.lastIntersection.z = fma(primitiveState.lastIntersection.z, dirlen, diffOffset);

    // setup min dist for limiting traverse
    traverseState.minDist = fma(traverseState.minDist, dirlen, diffOffset);
    
#ifdef USE_F32_BVH
    traverseState.directInv = fvec4_(dirproj);
#else
    traverseState.directInv = fvec4_(dirproj)*One1024.xxxx;
#endif
    traverseState.minusOrig = fma(fvec4_(torig), fvec4_(dirproj), fvec4_(diffOffset.xxxx));
    traverseState.boxSide.xyz = bsgn;


    [[dependency_infinite]]
    for (int hi=0;hi<max_iteraction;hi++) {
        [[flatten]]
        if (traverseState.idx >= 0 && traverseState.defTriangleID < 0) 
        { [[dependency_infinite]] for (;hi<max_iteraction;hi++) {
            bool _continue = false;
            const ivec2 cnode = traverseState.idx >= 0 ? (texelFetch(bvhMeta, traverseState.idx).xy-1) : (-1).xx;

            [[flatten]]
            if (cnode.x == cnode.y) { // if leaf, defer for intersection 
                [[flatten]]
                if (traverseState.defTriangleID < 0) { 
                    traverseState.defTriangleID = cnode.x;
                } else {
                    _continue = true;
                    //continue; 
                }
            } else { // if not leaf, intersect with nodes
                const int _cmp = cnode.x >> 1; // intersect boxes
                lowp bvec2_ childIntersect = bvec2_(traverseState.idx >= 0) & intersectCubeDual(traverseState.minusOrig.xyz, traverseState.directInv.xyz, traverseState.boxSide.xyz, 
                    fmat3x4_(bvhBoxes[_cmp][0], bvhBoxes[_cmp][1], bvhBoxes[_cmp][2])
                , nears, fars);

                // it increase FPS by filtering nodes by first triangle intersection
                childIntersect &= bvec2_(lessThanEqual(nears, primitiveState.lastIntersection.zz));
                childIntersect &= bvec2_(greaterThanEqual(fars, traverseState.minDist.xx));
                const int fmask = int(childIntersect.x + childIntersect.y*2u)-1; // mask of intersection

                [[flatten]]
                if (fmask >= 0) {
                    [[flatten]]
                    if (fmask == 2) { // if both has intersection
                        ivec2 ordered = cnode.xx + (nears.x<=nears.y ? ivec2(0,1) : ivec2(1,0));
                        //ivec2 ordered = nears.x<=nears.y ? cnode.xy : cnode.yx;
                        traverseState.idx = ordered.x;
                        IF (all(childIntersect) & bool_(!stackIsFull())) storeStack(ordered.y);
                    } else {
                        traverseState.idx = cnode.x + fmask;
                        //traverseState.idx = fmask == 0 ? cnode.x : cnode.y;
                    }

                    _continue = true; 
                    //continue;
                }
            }

            [[flatten]]
            if (!_continue) {
                // stacked 
                if (!stackIsEmpty()) {
                    traverseState.idx = loadStack();
                } else {
                    traverseState.idx = -1;
                }
            }

            // if all threads had intersection, or does not given any results, break for processing
            //IFALL
            IFANY 
            (traverseState.defTriangleID >= 0 || traverseState.idx < 0) { break; }
        }}
        
        [[flatten]]
        if (traverseState.defTriangleID >= 0) { doIntersection(); }
        [[flatten]]
        if (traverseState.idx < 0) { break; }
    }

    // correction of hit distance
    primitiveState.lastIntersection.z = max(fma(primitiveState.lastIntersection.z-diffOffset, 1.f/(dirlen*1.0009765625f), 1e-4f), 1e-4f);
}
