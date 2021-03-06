#pragma once

//#include "../../vRt_subimpl.inl"
#include "../Utils.hpp"

namespace _vt {
    using namespace vrt;

    VertexInputSet::~VertexInputSet() {
        if (_descriptorSet) vk::Device(VkDevice(*_device)).freeDescriptorSets(_device->_descriptorPool, { vk::DescriptorSet(_descriptorSet) });
        _descriptorSet = {};
    };

    // also, planned to add support of offsets in buffers 
    VtResult createVertexInputSet(std::shared_ptr<Device> _vtDevice,  VtVertexInputCreateInfo info, std::shared_ptr<VertexInputSet>& vtVertexInput) {
        VtResult result = VK_SUCCESS;
        //auto vtVertexInput = (_vtVertexInput = std::make_shared<VertexInputSet>());

        auto vkDevice = _vtDevice->_device;
        vtVertexInput = std::make_shared<VertexInputSet>();
        vtVertexInput->_device = _vtDevice;
        vtVertexInput->_attributeVertexAssembly = info.attributePipeline;

        // 
        VtDeviceBufferCreateInfo bfi = {};
        bfi.familyIndex = _vtDevice->_mainFamilyIndex;
        bfi.usageFlag = VkBufferUsageFlags(vk::BufferUsageFlagBits::eStorageBuffer);
        bfi.bufferSize = strided<uint32_t>(12);
        bfi.format = VK_FORMAT_UNDEFINED;

        // planned add external buffer support
        vtVertexInput->_uniformBlockBuffer = _vtDevice->_bufferTraffic[0]->_uniformVIBuffer; // use unified BUS only 
        vtVertexInput->_uniformBlock.primitiveCount = info.primitiveCount;
        vtVertexInput->_uniformBlock.verticeAccessor = info.verticeAccessor;
        vtVertexInput->_uniformBlock.indiceAccessor = info.indiceAccessor;
        vtVertexInput->_uniformBlock.materialID = info.materialID;
        vtVertexInput->_uniformBlock.primitiveOffset = info.primitiveOffset;
        vtVertexInput->_uniformBlock.attributeOffset = info.attributeOffset;
        vtVertexInput->_uniformBlock.attributeCount = info.attributeCount;
        vtVertexInput->_uniformBlock.bitfield = info.bitfield;
        vtVertexInput->_uniformBlock.materialAccessor = info.materialAccessor;

        // bind input buffer sources
        const auto vendorName = _vtDevice->_vendorName;
        //const auto inputCount = vendorName == VT_VENDOR_INTEL ? 1u : 8u;
        const auto inputCount = 8u;
        std::vector<vk::BufferView> sourceBuffers = {};
        const auto sourceBufferCount = std::min(info.sourceBufferCount, inputCount);
        for (auto i = 0u; i < sourceBufferCount; i++) { sourceBuffers.push_back(info.pSourceBuffers[i]); }
        for (auto i = sourceBufferCount; i < inputCount; i++) { sourceBuffers.push_back(sourceBuffers[sourceBufferCount-1]); }


        if (!info.bitfieldDetail.secondary) {

            // create descriptor sets
            std::vector<vk::DescriptorSetLayout> dsLayouts = { vk::DescriptorSetLayout(_vtDevice->_descriptorLayoutMap["vertexInputSet"]) };
            const auto&& dsc = vk::Device(vkDevice).allocateDescriptorSets(vk::DescriptorSetAllocateInfo().setDescriptorPool(_vtDevice->_descriptorPool).setPSetLayouts(&dsLayouts[0]).setDescriptorSetCount(1));
            vtVertexInput->_descriptorSet = std::move(dsc[0]);

            // write descriptors
             auto d1 = vk::DescriptorBufferInfo(info.bBufferRegionBindings, 0, VK_WHOLE_SIZE).setOffset(info.bufferRegionByteOffset);
             auto d2 = vk::DescriptorBufferInfo(info.bBufferViews, 0, VK_WHOLE_SIZE).setOffset(info.bufferViewByteOffset);
             auto d3 = vk::DescriptorBufferInfo(info.bBufferAccessors, 0, VK_WHOLE_SIZE).setOffset(info.bufferAccessorByteOffset);
             auto d4 = vk::DescriptorBufferInfo(info.bBufferAttributeBindings, 0, VK_WHOLE_SIZE).setOffset(info.attributeByteOffset);
             auto d5 = vk::DescriptorBufferInfo(vtVertexInput->_uniformBlockBuffer->_descriptorInfo());
             auto d6 = vk::DescriptorBufferInfo(info.bTransformData, 0, VK_WHOLE_SIZE).setOffset(info.transformOffset);

            // inline transform buffer create
            if (!d6.buffer) {
                VtDeviceBufferCreateInfo dbi = {};
                dbi.bufferSize = 16ull * sizeof(float);
                createBuffer(_vtDevice, dbi, vtVertexInput->_inlineTransformBuffer); // TODO - add support of constant shared buffer
                d6.setBuffer(vtVertexInput->_inlineTransformBuffer->_buffer);
            };

            // 
            const auto writeTmpl = vk::WriteDescriptorSet(vtVertexInput->_descriptorSet, 0, 0, 1, vk::DescriptorType::eStorageBuffer);
            std::vector<vk::WriteDescriptorSet> writes = {
                vk::WriteDescriptorSet(writeTmpl).setDstBinding(0).setDescriptorType(vk::DescriptorType::eUniformTexelBuffer).setDescriptorCount(inputCount).setPTexelBufferView(sourceBuffers.data()),
                vk::WriteDescriptorSet(writeTmpl).setDstBinding(1).setPBufferInfo(&d1),
                vk::WriteDescriptorSet(writeTmpl).setDstBinding(2).setPBufferInfo(&d2),
                vk::WriteDescriptorSet(writeTmpl).setDstBinding(3).setPBufferInfo(&d3),
                vk::WriteDescriptorSet(writeTmpl).setDstBinding(4).setPBufferInfo(&d4),
                vk::WriteDescriptorSet(writeTmpl).setDstBinding(5).setPBufferInfo(&d5),
                vk::WriteDescriptorSet(writeTmpl).setDstBinding(6).setPBufferInfo(&d6),
            };
            vk::Device(vkDevice).updateDescriptorSets(writes, {});
        };

        return result;
    };
};
