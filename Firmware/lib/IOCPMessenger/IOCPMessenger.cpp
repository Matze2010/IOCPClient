
extern "C"
{
#include <stdlib.h>
#include <stdarg.h>
}
#include <stdio.h>
#include "IOCPMessenger.h"

IOCPMessenger::IOCPMessenger(Stream &ccomms, const char *fld_separators, const char cmd_separator, const char *identifier) {
    init(ccomms, fld_separators, cmd_separator, identifier);
}

void IOCPMessenger::init(Stream &ccomms, const char *fld_separators, const char cmd_separator, const char *identifier) {
    default_callback = NULL;
    comms = &ccomms;
    print_newlines = true;
    field_separators = fld_separators;
    command_separator = cmd_separator;
    bufferLength = MESSENGERBUFFERSIZE;
    bufferLastIndex = MESSENGERBUFFERSIZE - 1;
    iocp_identifier = identifier;
    reset();

    callbackIndex = 0;
    default_callback = NULL;
    for (int i = 0; i < MAXCALLBACKS; i++) {
        callbackList[i].command = NULL;
        callbackList[i].callbackFunction = NULL;
    }

    pauseProcessing = false;
}

void IOCPMessenger::reset() {
    bufferIndex = 0;
    current = NULL;
    last = NULL;
    dumped = true;
}

void IOCPMessenger::feedinSerialData() {

    while (!pauseProcessing && comms->available())
    {
        // The Stream class has a readBytes() function that reads many bytes at once. On Teensy 2.0 and 3.0, readBytes() is optimized.
        // Benchmarks about the incredible difference it makes: http://www.pjrc.com/teensy/benchmark_usb_serial_receive.html

        int bytesAvailable = min(comms->available(), MAXSTREAMBUFFERSIZE);
        comms->readBytes(streamBuffer, bytesAvailable);

        // Process the bytes in the stream buffer, and handles dispatches callbacks, if commands are received
        for (int byteNo = 0; byteNo < bytesAvailable; byteNo++)
        {
            int messageState = processLine(streamBuffer[byteNo]);

            // If waiting for acknowledge command
            if ((messageState == kEndOfMessage) && isValidCommand()) {
                handleMessage();
            }
        }
    }
}

/**
 * Processes bytes and determines message state
 */
uint8_t IOCPMessenger::processLine(int serialByte) {

    messageState = kProccesingMessage;
    char serialChar = (char)serialByte;

    if (true) {

        if (serialChar == command_separator) {
            commandBuffer[bufferIndex] = '\0';

            if (bufferIndex > 0) {
                messageState = kEndOfMessage;
                current = commandBuffer;
                CmdlastChar = '\0';
            }
            reset();

        } else {
            commandBuffer[bufferIndex] = serialByte;
            bufferIndex++;
            if (bufferIndex >= bufferLastIndex) {
                reset();
            }
        }
    }
    return messageState;
}

/**
 * Dispatches attached callbacks based on command
 */
void IOCPMessenger::handleMessage() {

    lastCommand = readStringArg();
    char *commandPart = lastCommand + strlen(iocp_identifier); // Advance pointer by length of identifier

    bool called = false;
    
    for (int index = 0; index <= callbackIndex; index++) {
        messengerCallbackRegistration callbackEntry = callbackList[index];
        if (strcmp(commandPart, callbackEntry.command) == 0 && callbackEntry.callbackFunction != NULL) {
            (*callbackEntry.callbackFunction)();
            called = true;
        }
    }

    if (!called && default_callback != NULL) {
        (*default_callback)();
    }
}

bool IOCPMessenger::isValidCommand() {
    return (commandBuffer != NULL && strstr(commandBuffer, iocp_identifier) == commandBuffer);
}

char *IOCPMessenger::getLastCommand() {
    return lastCommand;
}

bool IOCPMessenger::next() {

    char *temppointer = NULL;
    // Currently, cmd messenger only supports 1 char for the field seperator
    switch (messageState)
    {
    case kProccesingMessage:
        return false;
    case kEndOfMessage:
        temppointer = commandBuffer;
        messageState = kProcessingArguments;
    default:
        if (dumped)
            current = strtok_r(temppointer, field_separators, &last);
        if (current != NULL)
        {
            dumped = true;
            return true;
        }
    }
    return false;
}

char *IOCPMessenger::readStringArg() {
    if (next()) {
        dumped = true;
        ArgOk = true;
        return current;
    }
    ArgOk = false;
    return '\0';
}

void IOCPMessenger::attach(messengerCallbackFunction newFunction) {
    default_callback = newFunction;
}

void IOCPMessenger::attach(const char *command, messengerCallbackFunction newFunction) {

    callbackIndex = min(callbackIndex, MAXCALLBACKS-1);
    messengerCallbackRegistration newEntry;

    newEntry.command = command;
    newEntry.callbackFunction = newFunction;

    callbackList[callbackIndex++] = newEntry;
}

void IOCPMessenger::sendCmdStart(const char *commandID) {
    if (!startCommand) {
        startCommand = true;
        pauseProcessing = true;
        comms->print(iocp_identifier);
        comms->print(commandID);
    }
}

void IOCPMessenger::sendCmdEnd() {

    if (startCommand) {

        comms->print(field_separators[0]);

        if (print_newlines) {
            comms->println(); // should append BOTH \r\n
        }
    }
    pauseProcessing = false;
    startCommand = false;
}

bool IOCPMessenger::available() {
    return next();
}
