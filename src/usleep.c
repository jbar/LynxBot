#include <stdlib.h>
#include <unistd.h>
#include <err.h>


int main(int argc, char * argv[])
{
    if (argc != 2) errx(-1,"Usage : %s [microseconds] .", argv[0]);
    usleep(atoi(argv[1]));
    return 0;
}

