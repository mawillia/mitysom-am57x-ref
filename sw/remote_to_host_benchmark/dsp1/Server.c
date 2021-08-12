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
 *  ======== Server.c ========
 *
 */

/* this define must precede inclusion of any xdc header file */
#define Registry_CURDESC Test__Desc
#define MODULE_NAME "Server"

/* xdctools header files */
#include <xdc/std.h>
#include <xdc/runtime/Assert.h>
#include <xdc/runtime/Diags.h>
#include <xdc/runtime/Log.h>
#include <xdc/runtime/Registry.h>

#include <stdio.h>

/* package header files */
#include <ti/ipc/MessageQ.h>
#include <ti/ipc/MultiProc.h>

#include <ti/sysbios/BIOS.h>
#include <ti/sysbios/knl/Task.h>
#include <ti/sysbios/hal/Cache.h>

/* local header files */
#include "../shared/AppCommon.h"
#include "RingBuffer.h"

/* module header file */
#include "Server.h"

/* module structure */
typedef struct {
    UInt16              hostProcId;         // host processor id
    MessageQ_Handle     slaveQue;           // created locally
} Server_Module;

/* private data */
Registry_Desc               Registry_CURDESC;
static Server_Module        Module;


/*
 *  ======== Server_init ========
 */
Void Server_init(Void)
{
    Registry_Result result;

    /* register with xdc.runtime to get a diags mask */
    result = Registry_addModule(&Registry_CURDESC, MODULE_NAME);
    Assert_isTrue(result == Registry_SUCCESS, (Assert_Id)NULL);

    /* initialize module object state */
    Module.hostProcId = MultiProc_getId("HOST");
}


/*
 *  ======== Server_create ========
 */
Int Server_create()
{
    Int                 status = 0;
    MessageQ_Params     msgqParams;
    char                msgqName[32];

    /* enable some log events */
    Diags_setMask(MODULE_NAME"+EXF");

    /* create local message queue (inbound messages) */
    MessageQ_Params_init(&msgqParams);
    sprintf(msgqName, App_SlaveMsgQueName, MultiProc_getName(MultiProc_self()));
    Module.slaveQue = MessageQ_create(msgqName, &msgqParams);

    if (Module.slaveQue == NULL) {
        status = -1;
        goto leave;
    }

    Log_print0(Diags_INFO,"Server_create: server is ready");

leave:
    Log_print1(Diags_EXIT, "<-- Server_create: %d", (IArg)status);
    return (status);
}


App_Msg* createAppMsg(UInt32 cmd)
{
    App_Msg *   msg;
    msg = (App_Msg *)MessageQ_alloc(0, sizeof(App_Msg));
    if (msg == NULL) {
        Log_print0(Diags_INFO, "Error: failed to allocate message\n");
        return NULL;
    }

    msg->cmd = cmd;
    return msg;
}


/*
 *  ======== Server_exec ========
 */
Int Server_exec()
{
    Int32                 status;
    Bool                running = TRUE;
    App_Msg *           msg;
    App_Msg *           txMsg;
    MessageQ_QueueId    queId;
    UInt32              i, k;
    void *            bufStart;
    RingBuffer* ringBuffer = NULL;
    UInt32              buffersLeftToSend;
    UInt32              payloadSize;
    Buffer              buffer;
    UInt32              buffersSent;

    Log_print0(Diags_ENTRY | Diags_INFO, "--> Server_exec:");


    while (running) {

        /* wait for inbound message */
        status = MessageQ_get(Module.slaveQue, (MessageQ_Msg *)&msg, MessageQ_FOREVER);

        if (status < 0) {
            goto leave;
        }

        if (msg->cmd == App_CMD_SHUTDOWN) {
            running = FALSE;
        }
        else if (msg->cmd == App_CMD_INIT) {
            if(ringBuffer != NULL)
                free(ringBuffer);

            Log_print0(Diags_INFO, "Init Received");
            ringBuffer = RingBuffer_initialize(msg->data.initData.phyStartAddress, msg->data.initData.ringBufferSize);
            buffersLeftToSend = 0;
            buffersSent = 0;
        }
        else if (msg->cmd == App_CMD_SEND) {
            Log_print0(Diags_INFO, "Send Received");
            queId = MessageQ_getReplyQueue(msg); /* type-cast not needed */

            if(msg->data.startData.payloadSize > ringBuffer->maxBufferSize)
            {
                Log_error0("Payload requested is greater than max buffer size");
                buffersLeftToSend = 0;
            }
            else
            {
                buffersLeftToSend = msg->data.startData.numBuffers;
                payloadSize = msg->data.startData.payloadSize;
                buffersSent = 0;
            }
        }
        else if (msg->cmd == App_CMD_BUFFER) {
            if(ringBuffer != NULL)
            {
                buffer.phyAddress = msg->data.bufferData.phyAddress;
                buffer.offset = msg->data.bufferData.offset;
                buffer.size = 0;
                RingBuffer_returnBuffer(ringBuffer, buffer);
            }
        }

        if(msg != NULL)
            MessageQ_free((MessageQ_Msg)msg);

        while(buffersLeftToSend > 0 && RingBufffer_isEmpty(ringBuffer) == 0)
        {
            status = RingBuffer_getBuffer(ringBuffer, &buffer);
            if(status == 0)
            {
                for(i = 0; i < payloadSize/sizeof(PayloadType); i++)
                {
                    ((PayloadType*)buffer.phyAddress)[i] = i+buffersSent;
                }
                
#if DSP_CACHE_WB == 1
                /* No speed up with FALSE */
                Cache_wb((char*)buffer.phyAddress, payloadSize, Cache_Type_ALL, TRUE);
#endif
                msg = createAppMsg(App_CMD_BUFFER);
                msg->data.bufferData.phyAddress = buffer.phyAddress;
                msg->data.bufferData.offset = buffer.offset;
                msg->data.bufferData.dataLen = payloadSize;

                MessageQ_put(queId, (MessageQ_Msg)msg);
                buffersLeftToSend--;
                buffersSent++;
            }
        }
    } /* while (running) */

leave:
    Log_print1(Diags_EXIT, "<-- Server_exec: %d", (IArg)status);
    return(status);
}

/*
 *  ======== Server_delete ========
 */

Int Server_delete()
{
    Int         status;

    Log_print0(Diags_ENTRY, "--> Server_delete:");

    /* delete the video message queue */
    status = MessageQ_delete(&Module.slaveQue);

    if (status < 0) {
        goto leave;
    }

leave:
    if (status < 0) {
        Log_error1("Server_finish: error=0x%x", (IArg)status);
    }

    /* disable log events */
    Log_print1(Diags_EXIT, "<-- Server_delete: %d", (IArg)status);
    Diags_setMask(MODULE_NAME"-EXF");

    return(status);
}

/*
 *  ======== Server_exit ========
 */

Void Server_exit(Void)
{
    /*
     * Note that there isn't a Registry_removeModule() yet:
     *     https://bugs.eclipse.org/bugs/show_bug.cgi?id=315448
     *
     * ... but this is where we'd call it.
     */
}
