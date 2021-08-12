#ifndef RingBuffer__include
#define RingBuffer__include

#include <xdc/std.h>

typedef struct 
{
    UInt32 phyAddress;
    UInt32 offset;
    UInt32 size;
}Buffer;

#define RINGBUFFER_NUMBER_OF_BUFFERS (4)
typedef struct
{
    UInt32 readIndex;
    UInt32 writeIndex;
    UInt32 fillCount;
    UInt32 maxBufferSize;
    Buffer buffers[RINGBUFFER_NUMBER_OF_BUFFERS];
}RingBuffer;

RingBuffer* RingBuffer_initialize(UInt32 phyStart, UInt32 ringBufferSize);
Int32 RingBuffer_getBuffer(RingBuffer* handle, Buffer* buffer);
Int32 RingBuffer_returnBuffer(RingBuffer* handle, Buffer buffer);
Int32 RingBufffer_isEmpty(RingBuffer* handle);
Int32 RingBufffer_isFull(RingBuffer* handle);


#endif
