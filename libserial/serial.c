#include <stdio.h>   /* Standard input/output definitions */
#include <string.h>  /* String function definitions */
#include <stdlib.h>
#include <unistd.h>  /* UNIX standard function definitions */
#include <fcntl.h>   /* File control definitions */
#include <errno.h>   /* Error number definitions */
#include <termios.h> /* POSIX terminal control definitions */
 
int OpenSerialPort(int serialSpeed)
{
    struct termios originalTTYAttrs;
    struct termios options;
    
    int fileDescriptor = -1;
 
    // Open the serial port read/write, with no controlling terminal, and don't wait for a connection.
    // The O_NONBLOCK flag also causes subsequent I/O on the device to be non-blocking.
    // See open(2) ("man 2 open") for details.
 
    fileDescriptor = open("/dev/tty.iap", O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fileDescriptor == -1)
    {
        fileDescriptor = -2;
        printf("Failed to open /dev/tty.iap; errno: %s (%d)\n", strerror(errno), errno);
        goto error;
    }
 
    // Note that open() follows POSIX semantics: multiple open() calls to the same file will succeed
    // unless the TIOCEXCL ioctl is issued. This will prevent additional opens except by root-owned
    // processes.
    // See tty(4) ("man 4 tty") and ioctl(2) ("man 2 ioctl") for details.
 
    if (ioctl(fileDescriptor, TIOCEXCL) == -1)
    {
        fileDescriptor = -3;
        goto error;
    }
 
    // Now that the device is open, clear the O_NONBLOCK flag so subsequent I/O will block.
    // See fcntl(2) ("man 2 fcntl") for details.
 
    if (fcntl(fileDescriptor, F_SETFL, 0) == -1)
    {
        fileDescriptor = -4;
        goto error;
    }
 
    // Get the current options and save them so we can restore the default settings later.
    if (tcgetattr(fileDescriptor, &originalTTYAttrs) == -1)
    {
        fileDescriptor = -5;
        goto error;
    }
 
    // The serial port attributes such as timeouts and baud rate are set by modifying the termios
    // structure and then calling tcsetattr() to cause the changes to take effect. Note that the
    // changes will not become effective without the tcsetattr() call.
    // See tcsetattr(4) ("man 4 tcsetattr") for details.
 
    options = originalTTYAttrs;
 
    // Set raw input (non-canonical) mode, with reads blocking until either a single character
    // has been received or a one second timeout expires.
    // See tcsetattr(4) ("man 4 tcsetattr") and termios(4) ("man 4 termios") for details.
 
    cfmakeraw(&options);
    options.c_cc[VMIN] = 1;
    options.c_cc[VTIME] = 10;
 
    // The baud rate, word length, and handshake options can be set as follows:
 
    cfsetspeed(&options, serialSpeed);    // Set 19200 baud
    options.c_cflag |= (CS8);  // RTS flow control of input
 
 
    // Cause the new options to take effect immediately.
    if (tcsetattr(fileDescriptor, TCSANOW, &options) == -1)
    {
        fileDescriptor = -6;
        goto error;
    }

    // Success
    return fileDescriptor;
 
    // Failure "/dev/tty.iap"
error:
    if (fileDescriptor != -1)
    {
        close(fileDescriptor);
    }
 
    return fileDescriptor;
}

ssize_t WriteSerial(int fd, void *buf, size_t n)
{
    int i;
    for (i = 0; i < n; i++) {
        write(fd, buf + i, 1);
    }
    
    return n;
}

ssize_t ReadSerial(int fd, void *buf, size_t n)
{
    int i;
    for (i = 0; i < n; i++) {
        read(fd, buf + i, 1);
    }
    
    return n;
}

void CloseSerial(int fd)
{
    close(fd);
}