

void traverseBVH2( in bool reset, in bool valid ) {
    primitiveState.lastIntersection.z = fma(min(primitiveState.lastIntersection.z, INFINITY), dirlen, traverseState.diffOffset);
    [[flatten]] if (reset) resetEntry(valid);
    [[flatten]] if (traverseState.maxElements <= 0 || primitiveState.lastIntersection.z < 0.f) { traverseState.idx = -1; };

    // two loop based BVH traversing
    vec4 nfe = vec4(0.f.xx, INFINITY.xx);
    [[dependency_infinite]] for (uint hi=0;hi<maxIterations;hi++) {
        [[flatten]] if (traverseState.idx >= 0 && traverseState.defElementID <= 0) {
        { [[dependency_infinite]] for (;hi<maxIterations;hi++) { bool _continue = false;
            //const NTYPE_ bvhNode = bvhNodes[traverseState.idx]; // each full node have 64 bytes
            #define bvhNode bvhNodes[traverseState.idx]
            const ivec2 cnode = traverseState.idx >= 0 ? bvhNode.meta.xy : (0).xx;
            [[flatten]] if (isLeaf(cnode.xy)) { traverseState.defElementID = VTX_PTR + cnode.x; } // if leaf, defer for intersection 
            else { // if not leaf, intersect with nodes
                //const fmat3x4_ bbox2x = fmat3x4_(bvhNode.cbox[0], bvhNode.cbox[1], bvhNode.cbox[2]);

#ifdef EXPERIMENTAL_UNORM16_BVH
                #define bbox2x fvec4_[3](\
                    fvec4_(traverseState.idx>=0?unpackSnorm4x16(bvhNode.cbox[0]):0.f.xxxx),\
                    fvec4_(traverseState.idx>=0?unpackSnorm4x16(bvhNode.cbox[1]):0.f.xxxx),\
                    fvec4_(traverseState.idx>=0?unpackSnorm4x16(bvhNode.cbox[2]):0.f.xxxx)\
                )
#else
                #define bbox2x (traverseState.idx>=0?bvhNode.cbox:fvec4_[3](0.f.xxxx,0.f.xxxx,0.f.xxxx)) // use same memory
#endif

                pbvec2_ childIntersect = bool(cnode.x&1) ? intersectCubeDual(traverseState.minusOrig.xyz, traverseState.directInv.xyz, bsgn, bbox2x, nfe) : false2_;

                // found simular technique in http://www.sci.utah.edu/~wald/Publications/2018/nexthit-pgv18.pdf
                // but we came up in past years, so sorts of patents may failure 
                // also, they uses hit queue, but it can very overload stacks, so saving only indices...
                childIntersect &= binarize(lessThanEqual(nfe.xy, fma(primitiveState.lastIntersection.z,fpOne,fpInner).xx)); // it increase FPS by filtering nodes by first triangle intersection

                // 
                pbool_ fmask = pl_x(childIntersect)|(pl_y(childIntersect)<<true_);
                [[flatten]] if (fmask > 0) { _continue = true;
                    int secondary = -1; 
                    [[flatten]] if (fmask == 3) { fmask &= true_<<pbool_(nfe.x>nfe.y); secondary = cnode.x^int(fmask>>1u); }; // if both has intersection
                    traverseState.idx = cnode.x^int(fmask&1u); // set traversing node id

                    // pre-intersection that triangle, because any in-stack op can't check box intersection doubly or reuse
                    // also, can reduce useless stack storing, and make more subgroup friendly triangle intersections
                    //#define snode (bvhNodes[secondary].meta.xy) // use reference only
                    [[flatten]] if (secondary > 0) {
                        const ivec2 snode = bvhNodes[secondary].meta.xy;
                        [[flatten]] if (isLeaf(snode)) { traverseState.defElementID = VTX_PTR + snode.x; secondary = -1; } else 
                        [[flatten]] if (secondary > 0) storeStack(secondary);
                    };
                };
            };

            // if all threads had intersection, or does not given any results, break for processing
            [[flatten]] if ( !_continue && traverseState.idx > 0 ) { traverseState.idx = -1, loadStack(traverseState.idx); } // load from stack 
            [[flatten]] IFANY (traverseState.defElementID > 0 || traverseState.idx <= 0) { break; } // 
        }}};

        // every-step solving 
        [[flatten]] IFANY (traverseState.defElementID > 0) { doIntersection( true, bsize ); } // if has triangle, do intersection
        [[flatten]] if (traverseState.idx <= 0) { break; } // if no to traversing - breaking
    };

    // correction of hit distance
    primitiveState.lastIntersection.z = min(fma(primitiveState.lastIntersection.z, invlen, -traverseState.diffOffset*invlen), INFINITY);
};
