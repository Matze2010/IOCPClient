#ifndef IOCPMessenger_h
#define IOCPMessenger_h

#include <inttypes.h>
#include <Arduino.h>

extern "C" {
    // callback functions always follow the signature: void cmd(void);
    typedef void (*messengerCallbackFunction)(void);
}

#define MAXCALLBACKS 30        // The maximum number of commands   (default: 50)
#define MESSENGERBUFFERSIZE 64 // The maximum length of the buffer (default: 64)
#define MAXSTREAMBUFFERSIZE 64 // The maximum length of the buffer (default: 32)
#define DEFAULT_TIMEOUT 5000   // Time out on unanswered messages. (default: 5s)

typedef struct callback_t {
    const char *command;
    messengerCallbackFunction callbackFunction;
} messengerCallbackRegistration;

// Message States
enum
{
    kProccesingMessage,   // Message is being received, not reached command separator
    kEndOfMessage,        // Message is fully received, reached command separator
    kProcessingArguments, // Message is received, arguments are being read parsed
};

class IOCPMessenger {

private:

    bool startCommand;                       // Indicates if sending of a command is underway
    char *lastCommand;                       // ID of last received command
    uint8_t bufferIndex;                     // Index where to write data in buffer
    uint8_t bufferLength;                    // Is set to MESSENGERBUFFERSIZE
    uint8_t bufferLastIndex;                 // The last index of the buffer
    char ArglastChar;                        // Bookkeeping of argument escape char
    char CmdlastChar;                        // Bookkeeping of command escape char
    bool pauseProcessing;                    // pauses processing of new commands, during sending
    bool print_newlines;                     // Indicates if \r\n should be added after send command
    char commandBuffer[MESSENGERBUFFERSIZE]; // Buffer that holds the data
    char streamBuffer[MAXSTREAMBUFFERSIZE];  // Buffer that holds the data
    uint8_t messageState;                    // Current state of message processing
    bool dumped;                             // Indicates if last argument has been externally read
    bool ArgOk;                              // Indicated if last fetched argument could be read
    char *current;                           // Pointer to current buffer position
    char *last;                              // Pointer to previous buffer position
    char prevChar;                           // Previous char (needed for unescaping)
    Stream *comms;                           // Serial data stream

    const char *field_separators;   // Character indicating end of argument (default: ',')
    const char *iocp_identifier;

    uint8_t callbackIndex;
    messengerCallbackFunction default_callback;                 // default callback function
    messengerCallbackRegistration callbackList[MAXCALLBACKS];   // list of attached callback functions

    void init(Stream &comms, const char *fld_separators, const char *identifier);
    void reset();

    inline uint8_t processLine(int serialByte) __attribute__((always_inline));
    inline void handleMessage() __attribute__((always_inline));
    inline bool isValidCommand() __attribute__((always_inline));

public:

    explicit IOCPMessenger(Stream &comms, const char *fld_separators = ":\r", const char *identifier = "Arn.");

    void feedinSerialData();
    bool next();
    bool available();

    char *readStringArg();
    char *getLastCommand();

    void attach(messengerCallbackFunction newFunction);
    void attach(const char *command, messengerCallbackFunction newFunction);

    void sendCmdStart(const char *commandID);
    void sendCmdEnd();

    template <class T>
    bool sendCmd(const char *commandID, T arg) {

        if (!startCommand)
        {
            sendCmdStart(commandID);
            sendCmdArg(arg);
            sendCmdEnd();
            return true;
        }
        return false;
    }

    template <class T>
    void sendCmdArg(T arg) {
        if (startCommand)
        {
            comms->print(field_separators[0]);
            comms->print(arg);
        }
    }
};

#endif 