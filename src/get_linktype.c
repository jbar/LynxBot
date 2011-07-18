#include <stdio.h>
#include <errno.h>
#include <error.h>

#define SIZEMAX 256

int main(int argc, char * argv[])
{
/*	const char inseq[]="[0;1m\017\033[33m\033[40m" ;
	const char outseq[]="[0m" ;
	char buf[(sizeof(inseq)>sizeof(outseq)?sizeof(inseq)-1:sizeof(outseq)-1)];
*/
	char current[SIZEMAX];
	FILE * fd;
	size_t ichar;
	int i;

	fd=fopen(argv[1],"r");
	if ( fd==NULL ) error(errno,errno,"argument %s",argv[1]);
// echo -e "\033[0;1m\017\033[33m\033[44mtest)
	while ( (ichar=fgetc(fd)) != EOF ) {
		if ( ( ichar == '\033' )
		  && ( fgetc(fd) == '[' )
		  && ( fgetc(fd) == '0' )
		  && ( fgetc(fd) == ';' )
		  && ( fgetc(fd) == '1' )
		  && ( fgetc(fd) == 'm' )
		  && ( ( (ichar=fgetc(fd)) == '\017' ) || ( ichar == '\033' ))
		  && ( ( ichar == '\033' )  || ( fgetc(fd) == '\033' ) )
		  && ( fgetc(fd) == '[' )
		  && ( fgetc(fd) == '3' )
		  && ( fgetc(fd) == '3' )
		  && ( fgetc(fd) == 'm' )
		  && ( fgetc(fd) == '\033' )
		  && ( fgetc(fd) == '[' )
		  && ( fgetc(fd) == '4' )
		  && ( fgetc(fd) == '4' )
		  && ( fgetc(fd) == 'm' ) ) {
			i=0;
			while ( (ichar=fgetc(fd)) == ' ' || ( ichar >= 'A' && ichar <= 'z' ) )
				if ( i < SIZEMAX-1 )
					current[i++]=ichar;
			current[i]='\0';
			if ( ichar == ')' )
				printf("%s\n",current);
		  }
	}
	fclose(fd);
	return(0);
}

