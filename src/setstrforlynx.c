#include <stdio.h>
#include <err.h>

int main(int argc, char * argv[])
{
	char * str = argv[1];

	if (argc !=2 ) errx(-1,"Usage : %s \"a string\" .", argv[0]);

	while ( *str != '\0' )
		printf("key %c\n",*str++);
	return(0);
}

