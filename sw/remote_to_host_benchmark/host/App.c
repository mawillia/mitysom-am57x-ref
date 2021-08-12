/*
 * Copyright (c) 2013-2014, Texas Instruments Incorporated
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * *  Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * *  Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * *  Neither the name of Texas Instruments Incorporated nor the names of
 *    its contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 *  ======== App.c ========
 *
 */

/* host header files */
#include <stdio.h>
#include <unistd.h>
#include <float.h>
#include <sys/time.h>


/* package header files */
#include <ti/ipc/Std.h>
#include <ti/ipc/MessageQ.h>
#include <ti/cmem.h>

/* local header files */
#include "../shared/AppCommon.h"
#include "App.h"

/* module structure */
typedef struct {
    MessageQ_Handle         hostQue;    // created locally
    MessageQ_QueueId        slaveQue;   // opened remotely
    UInt16                  heapId;     // MessageQ heapId
    UInt32                  msgSize;
} App_Module;

/* private data */
static App_Module Module;

/* Application specific defines */
//#define BIG_DATA_POOL_SIZE 0x1000000
#define BIG_DATA_POOL_SIZE 0x8000000
//#define BIG_DATA_POOL_SIZE 0x100000


/*
 *  ======== App_create ========
 */

Int App_create(UInt16 remoteProcId)
{
    Int                 status = 0;
    MessageQ_Params     msgqParams;
    char                msgqName[32];

    printf("--> App_create:\n");

    /* setting default values */
    Module.hostQue = NULL;
    Module.slaveQue = MessageQ_INVALIDMESSAGEQ;
    Module.heapId = App_MsgHeapId;
    Module.msgSize = sizeof(App_Msg);

    /* create local message queue (inbound messages) */
    MessageQ_Params_init(&msgqParams);

    Module.hostQue = MessageQ_create(App_HostMsgQueName, &msgqParams);

    if (Module.hostQue == NULL) {
        printf("App_create: Failed creating MessageQ\n");
        status = -1;
        goto leave;
    }

    /* open the remote message queue */
    sprintf(msgqName, App_SlaveMsgQueName, MultiProc_getName(remoteProcId));

    do {
        status = MessageQ_open(msgqName, &Module.slaveQue);
        sleep(1);
    } while (status == MessageQ_E_NOTFOUND);

    if (status < 0) {
        printf("App_create: Failed opening MessageQ\n");
        goto leave;
    }

    printf("App_create: Host is ready\n");

leave:
    printf("<-- App_create:\n");
    return(status);
}


/*
 *  ======== App_delete ========
 */
Int App_delete(Void)
{
    Int         status = 0;

    printf("--> App_delete:\n");

    /* close remote resources */
    status = MessageQ_close(&Module.slaveQue);

    if (status < 0) {
        goto leave;
    }

    /* delete the host message queue */
    status = MessageQ_delete(&Module.hostQue);

    if (status < 0) {
        goto leave;
    }

leave:
    printf("<-- App_delete:\n");
    return(status);
}

App_Msg* createAppMsg(UInt32 cmd)
{
    App_Msg *   msg;
    msg = (App_Msg *)MessageQ_alloc(Module.heapId, Module.msgSize);
    if (msg == NULL) {
        printf("Error: failed to allocate message\n");
        return NULL;
    }
    MessageQ_setReplyQueue(Module.hostQue, (MessageQ_Msg)msg);
    msg->cmd = cmd;

    return msg;
}

/*
 *  ======== App_exec ========
 */
Int App_exec(UInt32 numLoops, UInt32 numBuffers, UInt32 payloadSize)
{
    Int         status = 0;
    UInt32         loop;
    UInt32         batch;
    UInt32         msgCount = 0;
    App_Msg *   msg;
    struct timeval t1, t2;
    double elapsedTime;
    double minTime = DBL_MAX;
    double maxTime = 0;
    double averageTime = 0;
    double avgTimePerMsg = 0;
    CMEM_AllocParams cmemAttrs;
    void *sharedRegionAllocPtr=NULL;
    Int pool_id;
    UInt32 i;
    void* data;
    UInt64 bytesRx = 0;


    printf("--> App_exec:\n");

    printf("Number of Loops: %d\nSize of buffers: %d\nNumber of Buffers per loop: %d\nMessages per Loop: %d\n", numLoops, numBuffers, payloadSize, numBuffers);

    status = CMEM_init();
    if (status < 0) {
        printf("CMEM_init failed\n");
        goto leave;
    }
    else {
        printf("CMEM_init success\n");
    }

    pool_id = CMEM_getPool(BIG_DATA_POOL_SIZE);
    if (pool_id < 0) {
        printf("CMEM_getPool failed\n");
        goto leave;
    }
    printf("CMEM_getPool success\n");

    cmemAttrs.type = CMEM_HEAP;
#if ARM_CACHE_INV == 1
    cmemAttrs.flags =  CMEM_CACHED;
#else
    cmemAttrs.flags =  CMEM_NONCACHED;
#endif
    cmemAttrs.alignment = 0;
    sharedRegionAllocPtr = CMEM_allocPool(pool_id, &cmemAttrs);
    if (sharedRegionAllocPtr == NULL) {
        printf("CMEM_allocPool failed\n");
        goto leave;
    }

    printf("CMEM_allocPool success: Allocated buffer %p, phys: %x\n", sharedRegionAllocPtr, CMEM_getPhys(sharedRegionAllocPtr));

    printf("Tell DSP to initialize Ring Buffer\n");
    msg = createAppMsg(App_CMD_INIT);
    msg->data.initData.phyStartAddress = CMEM_getPhys(sharedRegionAllocPtr);
    msg->data.initData.ringBufferSize = BIG_DATA_POOL_SIZE;
    MessageQ_put(Module.slaveQue, (MessageQ_Msg)msg);

    printf("Starting Transfers\n");
    for(loop = 0; loop < numLoops; loop++)
    {
        msgCount = 0;
        msg = createAppMsg(App_CMD_SEND);
        msg->data.startData.numBuffers = numBuffers;
        msg->data.startData.payloadSize = payloadSize; 
        MessageQ_put(Module.slaveQue, (MessageQ_Msg)msg);
        gettimeofday(&t1, NULL);
        do
        {
            status = MessageQ_get(Module.hostQue, (MessageQ_Msg *)&msg, MessageQ_FOREVER);
            if(msg->cmd == App_CMD_BUFFER)
            {
                data = sharedRegionAllocPtr + msg->data.bufferData.offset;
#if ARM_CACHE_INV == 1
                CMEM_cacheInv(data, msg->data.bufferData.dataLen);
#endif
                for(i = 0; i < msg->data.bufferData.dataLen/sizeof(PayloadType); i++)
                {
                    if(i+msgCount != ((PayloadType*)data)[i])
                        printf("error: expected: %d, read: %d\n", i, ((PayloadType*)data)[i]);
                }
                bytesRx += msg->data.bufferData.dataLen;
                msgCount++;
            }
            MessageQ_setReplyQueue(Module.hostQue, (MessageQ_Msg)msg);
            MessageQ_put(Module.slaveQue, (MessageQ_Msg)msg);
        }while(msgCount != numBuffers);
        gettimeofday(&t2, NULL);
        elapsedTime = (t2.tv_sec - t1.tv_sec) * 1000.0;      // sec to ms
        elapsedTime += (t2.tv_usec - t1.tv_usec) / 1000.0;   // us to ms
        minTime = (minTime>elapsedTime)?elapsedTime:minTime;
        maxTime = (maxTime<elapsedTime)?elapsedTime:maxTime;
        averageTime += elapsedTime;
        printf("Bytes received: %llu, elapsed time: %f ms.\n", bytesRx, elapsedTime);
        printf("Data Rate: %f MBps\n", ((double)bytesRx/((double)elapsedTime / 1000.0))/1024.0/1024.0);
        printf("csvheader, Payload Size, Bandwidth (MB/s), Buffers Transferred, Payload Data Type Size (B), ARM Cache Inv, DSP Cache WB, Transfer Time (ms), Bytes Transferred\n");
        printf("csv, %d, %f, %d, %d, %d, %d, %f, %llu\n", payloadSize, ((double)bytesRx/((double)elapsedTime / 1000.0))/1024.0/1024.0, numBuffers, sizeof(PayloadType), ARM_CACHE_INV, DSP_CACHE_WB, elapsedTime, bytesRx);
/*
        msgCount = 0;
        gettimeofday(&t1, NULL);
        for(batch = 0; batch < numBatches; batch++)
        {
            // Create the send message
            msg = createAppMsg();
            if(msg == NULL)
                goto leave;
            msg->cmd = App_CMD_SEND;
            msg->numMessages = msgPerSend; 
            msg->phyAddress = CMEM_getPhys(sharedRegionAllocPtr);
            // TODO make sure this all power of 2
            msg->messageSize = bufSize;
            // Tell the DSP to start sending the ARM messages
            MessageQ_put(Module.slaveQue, (MessageQ_Msg)msg);
            // Loop, getting all the messages we told the DSP to send
            do
            {
                status = MessageQ_get(Module.hostQue, (MessageQ_Msg *)&msg, MessageQ_FOREVER);
                CMEM_cacheInv(sharedRegionAllocPtr, BIG_DATA_POOL_SIZE);
                data = (UInt32*)sharedRegionAllocPtr;
                printf("phyAddress: %x\n", msg->phyAddress);
                data += (msg->phyAddress - CMEM_getPhys(sharedRegionAllocPtr))/sizeof(UInt32);
                printf("shared: %p, data: %p\n", sharedRegionAllocPtr, data);
                for(i = 0; i < bufSize; i++)
                {
                    if(i != data[i])
                        printf("error: expected: %d, read: %d\n", i, data[i]);
                }
                if(status < 0)
                {
                    printf("Error: bad status from DSP message, status: %x\n", status);
                    goto leave;
                }
                msgCount++;
                MessageQ_free((MessageQ_Msg)msg);
            } while (msgCount % msgPerSend != 0);
        }
        gettimeofday(&t2, NULL);
        elapsedTime = (t2.tv_sec - t1.tv_sec) * 1000.0;      // sec to ms
        elapsedTime += (t2.tv_usec - t1.tv_usec) / 1000.0;   // us to ms
        minTime = (minTime>elapsedTime)?elapsedTime:minTime;
        maxTime = (maxTime<elapsedTime)?elapsedTime:maxTime;
        averageTime += elapsedTime;
        printf("Number messages received: %d, elapsed time: %f ms.\n", msgCount, elapsedTime);
        */
    }
    printf("Transfers Complete\n");
    averageTime = averageTime/numLoops;
    printf("Min time: %f ms, Average Time: %f ms Max time: %f ms\n", minTime, averageTime, maxTime);
    avgTimePerMsg = averageTime/(payloadSize*numBuffers);
    printf("Average transfer time per message: %f ms\n", avgTimePerMsg);

leave:
    printf("<-- App_exec: %d\n", status);
    if (sharedRegionAllocPtr) {
        /* free the message */
        CMEM_free(sharedRegionAllocPtr, &cmemAttrs);
    }
    return(status);
}
