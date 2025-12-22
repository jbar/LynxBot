#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <error.h>
#include <err.h>

#define SIZEMAX 256
#define SIZEMAXTYPE 32

int main(int argc, char * argv[])
{
    char current[SIZEMAX],currenttype[SIZEMAX];
    FILE * flink, * ftype, * ferror;
    size_t ichar,jchar;
    unsigned int i,nbla=0;

    if (argc !=4 ) errx(-1,"Usage : %s \"link file\" \"linktype file\" \"error file\" < a_lynx_output.", argv[0]);

    if ( stdin==NULL ) error(errno,errno,"argument %s",argv[1]);
    while ( (ichar=fgetc(stdin)) != EOF ) {
        if ( ( ichar == '\033' )
       /*   && ( fgetc(stdin) == '[' )
          && ( fgetc(stdin) == '0' )
          && ( fgetc(stdin) == ';' )
          && ( fgetc(stdin) == '1' )
          && ( fgetc(stdin) == 'm' )
          && ( (ichar=fgetc(stdin)) == '\017' || ichar == '\033')
          && ( ichar == '\033' || fgetc(stdin) == '\033' ) */
          && ( fgetc(stdin) == '[' )
          && ( fgetc(stdin) == '3' )
          && ( fgetc(stdin) == '3' )
          && ( fgetc(stdin) == 'm' )
          && ( fgetc(stdin) == '\033' )
          && ( fgetc(stdin) == '[' )
          && ( fgetc(stdin) == '4' )
	  /* a 0 here indicate a link (bold yellow), a 4 indicate the status bar (yellow on blue), and a 1 may indicate an error (Alert!) depending on lynx version : older version indicate Alert in the standard status bar */
          && ( (jchar=fgetc(stdin)) == '0' || jchar == '4' || jchar== '1' )
          && ( fgetc(stdin) == 'm' ) ) {
            i=0;
            while ( (ichar=fgetc(stdin)) != EOF && ichar != '\033' 
                    && ( jchar!='4' || ichar == ' ' || ichar == '(' || ( ichar >= 'A' && ichar <= 'z' ) || ichar == '%' || ichar == '"' ) )
                if ( i < SIZEMAX-1 && ( jchar!='4' || ichar != '(' ) )
                    current[i++]=ichar;

            current[i]='\0';

            if ( jchar == '1' && ! strncmp(current,"Alert",5) ) {
                ferror=fopen(argv[3],"w");
                if ( ferror==NULL ) error(errno,errno,"can't open \"%s\" for writing",argv[3]);
                fprintf(ferror,"%s\n",current);
                fclose(ferror);
            }
            else if ( jchar == '0' ) {
                /* jchar==0 means color 40 which lynx reserve for selected link */
                nbla++;

                flink=fopen(argv[1],"w");
                if ( flink==NULL )
                    error(errno,errno,"can't open \"%s\" for writing",argv[1]);
                fprintf(flink,"%10u %s\n",nbla,current);
                fclose(flink);

                /* next block update nbla in file argv[2], in case currenttype didn't change*/
                ftype=fopen(argv[2],"w");
                if ( ftype==NULL )
                        error(errno,errno,"can't open \"%s\" for writing",argv[2]);
                fprintf(ftype,"%10u %s\n",nbla,currenttype);
                fclose(ftype);
            }
            else if ( ichar == ')' ) {
                strcpy(currenttype,current);
                ftype=fopen(argv[2],"w");
                if ( ftype==NULL ) error(errno,errno,"can't open \"%s\" for writing",argv[2]);
                fprintf(ftype,"%10u %s\n",nbla,currenttype);
                fclose(ftype);
            }
            else {
		/* There is no currenttype in the status bar. It happen at least when there is no link on the viewed section */
                ftype=fopen(argv[2],"w");
                if ( ftype==NULL ) error(errno,errno,"can't open \"%s\" for writing",argv[2]);
                fprintf(ftype,"%10u Unknow\n",nbla);
                fclose(ftype);
            }

        }
    }
    return(0);
}

