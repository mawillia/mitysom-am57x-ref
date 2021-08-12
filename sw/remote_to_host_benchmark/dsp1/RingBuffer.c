#include "RingBuffer.h"

RingBuffer* RingBuffer_initialize(UInt32 phyStart, UInt32 ringBufferSize)
{
    UInt32 i;
    RingBuffer* handle;
    Buffer tempBuffer;

    // Initialize handle
    handle = malloc(sizeof(RingBuffer));
    handle->readIndex = 0;
    handle->writeIndex = 0;
    handle->fillCount = 0;
    handle->maxBufferSize = ringBufferSize/RINGBUFFER_NUMBER_OF_BUFFERS;

    for(i = 0; i < RINGBUFFER_NUMBER_OF_BUFFERS; i++)
    {
        tempBuffer.offset = i * handle->maxBufferSize;
        tempBuffer.phyAddress = phyStart + tempBuffer.offset;
        tempBuffer.size = 0;
        RingBuffer_returnBuffer(handle, tempBuffer);
    }

    return handle;
}

Int32 RingBuffer_getBuffer(RingBuffer* handle, Buffer* buffer)
{
    if(buffer == NULL)
        return -2;

    if(RingBufffer_isEmpty(handle) == 0)
    {
        *buffer = handle->buffers[handle->readIndex];
        handle->readIndex = (handle->readIndex+1) % RINGBUFFER_NUMBER_OF_BUFFERS;
        handle->fillCount--;
    }
    else
        return -1;

    return 0;
}

Int32 RingBuffer_returnBuffer(RingBuffer* handle, Buffer buffer)
{
    if(RingBufffer_isFull(handle) == 0)
    {
        handle->buffers[handle->writeIndex] = buffer;
        handle->writeIndex = (handle->writeIndex + 1) % RINGBUFFER_NUMBER_OF_BUFFERS;
        handle->fillCount++;
    }
    else
    {
        return -1;
    }
    return 0;
}

Int32 RingBufffer_isEmpty(RingBuffer* handle)
{
    if(handle->fillCount == 0)
        return 1;

    return 0;
}

Int32 RingBufffer_isFull(RingBuffer* handle)
{
    if(handle->fillCount == RINGBUFFER_NUMBER_OF_BUFFERS)
        return 1;

    return 0;
}