/*
 ============================================================================
 Name        : dma_checker.c
 Author      : 
 Version     :
 Copyright   : Your copyright notice
 Description : Hello World in C, Ansi-style
 ============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <netdb.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>
#include <argp.h>

/* Program documentation. */
static char doc[] = "checks coninuity of test data from zedboard";

/* A description of the arguments we accept. */
static char args_doc[] = "";

/* The options will be parsed. */
static struct argp_option options[] = {
        { "port", 'p', "PORT_NR", 0, "listening port. default 5632" },
        { "naggle", 'n', "1/0", 0, "Enable naggle algorithm? Default=0 !" },
        { "debug_level", 'd', "LEVEL", 0, "Debug level. Default=0" },
        { "buffer_size", 'b', "BYTES", 0, "used buffer size for dma->TCP operation. Default: 65536" },
        { "host", 'h', "IP_ADDRESS", 0, "IP address of the server. 192.168.1.31?" },

        { 0 }
};

/* Used by main to communicate with parse_opt. */
struct arguments_t {
	int port;
	int naggle;
	int debug_level;
	int buffer_size;
	char* host;
};
struct arguments_t arguments;

void arguments_init(struct arguments_t* arguments) {
	/* Default values. */
	arguments->port = 5632;
	arguments->naggle = 0;
	arguments->debug_level = 0;
	arguments->buffer_size = 1 * 1024;
	arguments->host = "192.168.1.31";
}

void arguments_print(struct arguments_t* arguments) {
	printf("#port=%d\n", arguments->port);
	printf("#host=\"%s\"\n", arguments->host);
	printf("#naggle=\"%d\"\n", arguments->naggle);
	printf("#debug_level=\"%d\"\n", arguments->debug_level);
	printf("#buffer_size=\"%d\"\n", arguments->buffer_size);
}

/* Parse a single option. */
static error_t parse_opt(int key, char *arg, struct argp_state *state) {
	/* Get the input argument from argp_parse, which we
	 know is a pointer to our arguments structure. */
	struct arguments_t *arguments = state->input;

	switch (key) {
		case 'p':
			arguments->port = atoi(arg);
			break;
		case 'n':
			arguments->naggle = atoi(arg);
			break;
		case 'h':
			arguments->naggle = arg;
			break;
		case 'd':
			arguments->debug_level = atoi(arg);
			break;
		case 'b':
			arguments->buffer_size = atoi(arg);
			break;
		case ARGP_KEY_END:
			break;
		default:
			return ARGP_ERR_UNKNOWN;
	}
	return 0;
}
/* argp parser. */
static struct argp argp = { options, parse_opt, args_doc, doc };

int main(int argc, char *argv[]) {
	arguments_init(&arguments);
	argp_parse(&argp, argc, argv, 0, 0, &arguments);
	arguments_print(&arguments);

	unsigned char buf[arguments.buffer_size];
	struct sockaddr_in their_addr; /* connector's address information */
	int sockfd;

	struct hostent *he;
	if ((he = gethostbyname(arguments.host)) == NULL) { /* get the host info */
		herror("gethostbyname");
		exit(1);
	}
	if ((sockfd = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
		perror("socket");
		exit(1);
	}

	their_addr.sin_family = AF_INET; /* host byte order */
	their_addr.sin_port = htons(arguments.port); /* short, network byte order */
	their_addr.sin_addr = *((struct in_addr *) he->h_addr);
	bzero(&(their_addr.sin_zero), 8); /* zero the rest of the struct */
	if (connect(sockfd, (struct sockaddr *) &their_addr,
	        sizeof(struct sockaddr)) == -1) {
		perror("connect");
		exit(1);
	}
	int numbytes;
	uint32_t counter = 0;
	while (1) {
		if ((numbytes = recv(sockfd, buf, sizeof(buf), 0)) == -1) {
			perror("recv");
			exit(1);
		}
		if (numbytes & 0x03) {
			fprintf(stderr, "wrong number of read bytes: %d \n", numbytes);
		}
		numbytes = numbytes >> 2;
		uint32_t *bufp = (uint32_t*) buf;
		while (numbytes) {
			numbytes = numbytes - 1;
			uint32_t newval = bufp[0];
			if (newval != counter) {
				fprintf(stderr, "Error. Expected:0x%08x, received:0x%08x\n", counter, newval);
				counter=newval;
			}
			counter++;
//			printf("%08x ", bufp[0]);
			bufp++;
		}
//		printf("Received:");
//		for(i=0;i<numbytes;i++){
//			printf("%02x ",buf[i]);
//		}
	}

	close(sockfd);

	return EXIT_SUCCESS;
}

#define PORT 3490    /* the port client will be connecting to */
#define MAXDATASIZE 100 /* max number of bytes we can get at once */

int delete(int argc, char *argv[])
{
	int sockfd, numbytes;
	char buf[MAXDATASIZE];
	struct hostent *he;
	struct sockaddr_in their_addr; /* connector's address information */

	if (argc != 2) {
		fprintf(stderr, "usage: client hostname\n");
		exit(1);
	}

	if ((he = gethostbyname(argv[1])) == NULL) { /* get the host info */
		herror("gethostbyname");
		exit(1);
	}

	if ((sockfd = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
		perror("socket");
		exit(1);
	}

	their_addr.sin_family = AF_INET; /* host byte order */
	their_addr.sin_port = htons(PORT); /* short, network byte order */
	their_addr.sin_addr = *((struct in_addr *) he->h_addr);
	bzero(&(their_addr.sin_zero), 8); /* zero the rest of the struct */

	if (connect(sockfd, (struct sockaddr *) &their_addr,
	        sizeof(struct sockaddr)) == -1) {
		perror("connect");
		exit(1);
	}
	while (1) {
		if (send(sockfd, "Hello, world!\n", 14, 0) == -1) {
			perror("send");
			exit(1);
		}
		printf("After the send function \n");

		if ((numbytes = recv(sockfd, buf, MAXDATASIZE, 0)) == -1) {
			perror("recv");
			exit(1);
		}

		buf[numbytes] = '\0';

		printf("Received in pid=%d, text=: %s \n", getpid(), buf);
		sleep(1);

	}

	close(sockfd);

	return 0;
}

