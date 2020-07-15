/*******************************************************************************
 A simple server which provides communication between PL and outside world over
 TCP
 The port number is passed as an argument
 This version runs forever, forking off a separate
 process for each connection
 *******************************************************************************/

//#include <bits/socket_type.h>
//#include <asm-generic/errno-base.h>
//#include <bits/socket_type.h>
#define _GNU_SOURCE
#include <sched.h>
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>
#include <poll.h>
#include <argp.h>
#include <sys/sendfile.h>



#define RD_PATH "/dev/axidmard"
#define WR_PATH "/dev/axidmawr"

void dordstuff(int sock);
void dowrstuff(int sock);

/* Program documentation. */
static char doc[] = "BIF vs SPIROC data correlation tool. For more info try --help";

/* A description of the arguments we accept. */
static char args_doc[] = "";

/* The options will be parsed. */
static struct argp_option options[] =
        {
                { "port", 'p', "PORT_NR", 0, "listening port. default 5632" },
                { "naggle", 'n', "1/0", 0, "Enable naggle algorithm? Default=0 !" },
                { "debug_level", 'd', "LEVEL", 0, "Debug level. Default=0" },
                { "zero_copy", 'z', 0, 0, "Use zero-copy (NOT SUPPORTED YET). Default=0" },
                { "buffer_size", 'b', "BYTES", 0, "used buffer size for dma->TCP operation. Default: 65536" },
                { "blocking_read", 'l', "1/0", 0, "use blocking read instead of non-blocking" },
                { "affinity", 'a', "CPU_NR", 0, "tie the application to specific CPU. Default: -1 (not used)" },
                { "priority", 'r', "NICE", 0, "change the priority: Negative value=tie the application to specific CPU. Default: -1 (not used)" },
                { "full_packets", 'f', "1/0", 0, "wait for the full packet from TCP?" },

                { 0 } };

/* Used by main to communicate with parse_opt. */
struct arguments_t {
	int port;
	int naggle;
	int debug_level;
	int zero_copy;
	int buffer_size;
	int blocking_read;
	int affinity;
	int priority;
	int full_packets;
};
struct arguments_t arguments;

void arguments_init(struct arguments_t* arguments) {
	/* Default values. */
	arguments->port = 5632;
	arguments->naggle = 0;
	arguments->debug_level = 0;
	arguments->zero_copy = 0;
	arguments->buffer_size = 64 * 1024;
	arguments->blocking_read = 0;
	arguments->affinity = -1;
	arguments->priority = 0;
	arguments->full_packets = 1;
}

void arguments_print(struct arguments_t* arguments) {
	printf("#port=%d\n", arguments->port);
	printf("#naggle=\"%d\"\n", arguments->naggle);
	printf("#debug_level=\"%d\"\n", arguments->debug_level);
	printf("#zero_copy=\"%d\"\n", arguments->zero_copy);
	printf("#buffer_size=\"%d\"\n", arguments->buffer_size);
	printf("#blocking_read=\"%d\"\n", arguments->blocking_read);
	printf("#affinity=\"%d\"\n", arguments->affinity);
	printf("#priority=\"%d\"\n", arguments->priority);
	printf("#full_packets=\"%d\"\n", arguments->full_packets);
}

/* Parse a single option. */
static error_t parse_opt(int key, char *arg, struct argp_state *state) {
	/* Get the input argument from argp_parse, which we
	 know is a pointer to our arguments structure. */
  struct arguments_t *arguments = (struct arguments_t *)state->input;

	switch (key) {
		case 'p':
			arguments->port = atoi(arg);
			break;
		case 'n':
			arguments->naggle = atoi(arg);
			break;
		case 'd':
			arguments->debug_level = atoi(arg);
			break;
		case 'z':
			arguments->zero_copy = 1;
			break;
		case 'b':
			arguments->buffer_size = atoi(arg);
			break;
		case 'l':
			arguments->blocking_read = atoi(arg);
			break;
		case 'a':
			arguments->affinity = atoi(arg);
			break;
		case 'f':
			arguments->full_packets = atoi(arg);
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

void sigchld_handler(int s) {
	while (waitpid(-1, NULL, WNOHANG) > 0)
		;
}

volatile int running;

void end_running(int sig) {
	switch (sig) {
		case SIGUSR1:
			running = 0;
			printf("received SIGUSR1\n");
			break;
		case SIGUSR2:
			break;
		default:
			break;
	}
}

/*
 * debug level.
 * 0 = basic info, no prints during data sending
 * 1 = basic info, prints "." during data sending
 * 2 = prints headers
 * 3 = prints all
 */

int main(int argc, char *argv[]) {
	arguments_init(&arguments);
	argp_parse(&argp, argc, argv, 0, 0, &arguments);
	arguments_print(&arguments);

	/*cpu affinity*/
	if (arguments.affinity >= 0) {
		cpu_set_t cpu_set;
		CPU_ZERO(&cpu_set);
		CPU_SET(arguments.affinity, &cpu_set);
		if (sched_setaffinity(0, sizeof(cpu_set_t), &cpu_set) != 0) {
			fprintf(stderr, "sched_setaffinity failed errno=%d\n", errno);
			return -1;
		}
	}

	printf("xldas started\n");
	int sockfd, newsockfd, portno, pid;
	portno = arguments.port;

	struct sockaddr_in serv_addr, cli_addr;
	struct sigaction sa;

	socklen_t clilen;
	sockfd = socket(PF_INET, SOCK_STREAM, 0);
	if (sockfd < 0)
		fprintf(stderr, "ERROR opening socket");
	bzero((char *) &serv_addr, sizeof(serv_addr));

	/*allow reuse the socket binding in case of restart after fail*/
	int itrue = 1;
	setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &itrue, sizeof(itrue));

	//portno = atoi(argv[1]);
	serv_addr.sin_family = AF_INET;
	serv_addr.sin_addr.s_addr = INADDR_ANY;
	serv_addr.sin_port = htons(portno);
	if (bind(sockfd, (struct sockaddr *) &serv_addr, sizeof(serv_addr)) < 0)
		fprintf(stderr, "ERROR on binding. errno=%d\n", errno);
	listen(sockfd, 1);

	sa.sa_handler = sigchld_handler; // reap all dead processes
	sigemptyset(&sa.sa_mask);
	/* SA_RESTART causes interrupted system calls to be restarted */
	sa.sa_flags = SA_RESTART;
	if (sigaction(SIGCHLD, &sa, NULL) == -1) {
		fprintf(stderr, "sigaction failed");
		exit(1);
	}

	clilen = sizeof(cli_addr);
	while (1) {
		running = 1; //lets assume for all processes that the socket is open after accepting
		newsockfd = accept(sockfd, (struct sockaddr *) &cli_addr, &clilen); //wait for the connection
		if (newsockfd < 0)
			fprintf(stderr, "ERROR on accept");
		// Fork read process
		pid = fork();
//		join
		if (pid < 0)
			fprintf(stderr, "ERROR on forking");
		if (pid == 0) { //succesful connect, child process
			signal(SIGUSR1, end_running); // register a signal handler for the child, which will gently stop the dordstuff, which does not have any other means of knowing, that the connection was closed
			if (arguments.debug_level) {
				printf("new connection from 0%d.%d.%d.%d\n", (cli_addr.sin_addr.s_addr & 0xFF), (cli_addr.sin_addr.s_addr & 0xFF00) >> 8,
				        (cli_addr.sin_addr.s_addr & 0xFF0000) >> 16, (cli_addr.sin_addr.s_addr & 0xFF000000) >> 24);
			}
			close(sockfd); //the forked process contains a copy of the sockfd, which is not needed and would make a problem if we wouldn't closed it
			dordstuff(newsockfd);  //we will send the data from lda to TCP
			close(newsockfd);
			exit(0);
		} else { // the original process, which serves as a read process
			dowrstuff(newsockfd); //we will copy the data from the TCP to the LDA
			int childExitStatus;
			close(newsockfd);
			if (arguments.debug_level)
				printf("Sending SIGUSR1\n");
			kill(pid, SIGUSR1); //send the signal to dordstuff
			if (arguments.debug_level)
				printf("Waiting for the read process to finish\n");
			waitpid(pid, &childExitStatus, 0);
			if (arguments.debug_level)
				printf("the RD process also died. Processes joined\n");
		}
	} /* end of while */
	printf("Closing TCP socket\n");
	close(sockfd);

	return 0; /* we never get here */
}
/* reads from the PL and transmit to teh TCP*/

/**
 * sock: tcp connection
 */
void dordstuff(int sock) {
	int written; //number of written bytes
	unsigned char pl_rd_buf[arguments.buffer_size];
	int pln1, pln2 = 0; //number of bytes read from the pl

	bzero(pl_rd_buf, sizeof(pl_rd_buf)); //clear the buffer

	int bytes_read; //how many bytes was read by the read() function from DMA device node
	int packet_size, qword_num;
	int cpid = getpid();    // This child's process ID

	/*disables nagle algorithm*/
	if (arguments.naggle == 0) {
		int flag = 1;
		setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, (char *) &flag, sizeof(int));
	} else {
		// Nagle alg is enabled by default
	}
	int dma_rd;    // file descriptor
	if (arguments.blocking_read) {
		dma_rd = open(RD_PATH, O_RDONLY);
	} else {
		dma_rd = open(RD_PATH, O_RDONLY | O_NONBLOCK);
	}

	if (dma_rd < 0)
		fprintf(stderr, "ERROR opening PL device to read from\n");
//	while ((bytes_read = read(dma_rd, fifo_buf, sizeof(fifo_buf))) >= 0) { //the read from the PL may return 0 as a valid amount
//		buf_wptr = fifo_buf; //copy the starting point of the buffer
//		while (bytes_read > 0) {
//			bytes_written = write(fifod, buf_wptr, bytes_read);
//			if (debug_output) {
//				printf("_%d_", bytes_written);
//				fflush(stdout);
//			}
//			if (bytes_written < 0) perror("child - write");
//			buf_wptr += bytes_written; //increment the buffer writing pointer
//			bytes_read -= bytes_written; //and update the bytes_read variable to the actually remaining bytes to write
//		}
//	}
	if (arguments.zero_copy) {
		while (running == 1) {
			/* TODO not working !!! */
			int ret = sendfile(sock, dma_rd, NULL, arguments.buffer_size);
			if (ret == -1) {
				fprintf(stderr, "ERROR using sendfile. errno=%d\n", errno);
			}
			if (arguments.debug_level) {
				if (ret > 0) {
					fprintf(stdout, "copied %d bytes\n", ret);
				}
			}
		}
	} else {
		while (running == 1) { //the running signal is deasserted by the SIGUSR1 signal
			bytes_read = read(dma_rd, pl_rd_buf, sizeof(pl_rd_buf));
			if (bytes_read < 0) {
				if (errno == EAGAIN)
					continue; //no problem, just no data
				fprintf(stderr, "ERROR on reading from axidmard, errno=%d\n", errno);
				//handle errors
			} else if (bytes_read > 0) {
				switch (arguments.debug_level) {
					case 0:
						break;
					case 1:
						printf("Writing %d bytes to the TCP\n", bytes_read);
						break;
					default:
						printf("Writing %d bytes to the TCP\n", bytes_read);
						break;
				}
				int sum_written = 0;
				unsigned char *writeptr = pl_rd_buf;
				while (bytes_read > 0) {
					written = write(sock, writeptr, bytes_read);
					if (written < 0) {
						fprintf(stderr, "ERROR writing to the TCP socket. errno: %d\n", errno);
						if (errno == EPIPE) {
							goto sock_is_closed_rd;
						}
					} else {
						bytes_read -= written;
						writeptr += written;
					}
				}
			}
		}
	}
	sock_is_closed_rd: ; //close(fhrd);
}
/* listen to the TCP and write all data from tcp to PL*/
void dowrstuff(int sock) {
	int recieved;
	unsigned char tcp_rd_buf[4096] = { };		// A buffer for data coming over TCP
	unsigned char pl_wr_buf[4096] = { };
	int tcp_rx_size, dword_num;			// Size of incoming TCP packet (excluding 4B for size)
	int fhwr;

	fhwr = open(WR_PATH, O_WRONLY);
	if (fhwr < 0)
		fprintf(stderr, "ERROR opening PL device to write to");

	bzero(tcp_rd_buf, 4096);
	if (arguments.full_packets) {
		for (;;) { /*wait for the full packets*/
			recieved = read(sock, tcp_rd_buf, 4); //read the header with the length
//		printf("Result of the TCP read: %d\n", n);
			if (recieved < 0) { //error???
				fprintf(stderr, "ERROR reading from TCP socket, %d\n", errno);
				break;
			} else if (recieved == 0) { //the connection is closed. We close
				goto conn_is_closed_wr;
			} else {
				printf("<\n");
				tcp_rx_size = (*((uint32_t *) (tcp_rd_buf))) & 0x0FFF; //use first 4 bytes of the buffer as short int. limit the outgoing packet length to 4096 B
				dword_num = (tcp_rx_size + 4 - 1) / 4;
				if (arguments.debug_level >= 2)
					printf("Incoming TCP data: %d Bytes / %d Dwords\n", tcp_rx_size, dword_num);
				recieved = read(sock, (tcp_rd_buf + 4), tcp_rx_size); //read the full packed with the known length
				printf("TCP Packet read result: %d\n", recieved);
				if (recieved < 0) { //error???
					fprintf(stderr, "ERROR reading from TCP socket, %d\n", errno);
					break;
				} else if (recieved == 0) { //the connection is closed. We close
					if (arguments.debug_level)
						printf("Connection closed. We also close\n");
					goto conn_is_closed_wr;
				} else {
					if ((tcp_rd_buf[0] & 0x02)) {
						if (arguments.debug_level)
							printf("Odd number of words, adding an extra word\n");
						tcp_rd_buf[tcp_rx_size + 4] = (unsigned char) 0;
						tcp_rd_buf[tcp_rx_size + 5] = (unsigned char) 0;
						tcp_rx_size = tcp_rx_size + 2;
					}
					if (arguments.debug_level > 2) {

						printf("Data(hex):"); //we print the rx buffer
						int i;
						for (i = 0; i < tcp_rx_size + 4; i++) {
							printf(",%02X", tcp_rd_buf[i]);
						}
						printf("\n");
					}
					int n_to_send = dword_num * 4 + 4; //number of bytes to be sent
					memcpy(pl_wr_buf, tcp_rd_buf, n_to_send);
					while (n_to_send > 0) { //cycle until all data is written
//					printf("Writing %d bytes to the pl\n", n_to_send);
						recieved = write(fhwr, pl_wr_buf, n_to_send);
//					printf("Written %d bytes to the pl\n", n);
						if (recieved < 0) {
							fprintf(stderr, "ERROR writing to the PL device\n");
							break;
						}
						n_to_send -= recieved;
					}
					printf(">");
					fflush(stdout);
				};
			};
		}
	} else {/*simple copy*/
		while (1) {
			recieved = read(sock, tcp_rd_buf, 4096);
			if (recieved < 0) { //error???
				fprintf(stderr, "ERROR reading from TCP socket, %d\n", errno);
				break;
			} else if (recieved == 0) { //the connection is closed. We close
				goto conn_is_closed_wr;
			} else {
				int written = write(fhwr, tcp_rd_buf, recieved);
				if (arguments.debug_level)
					printf("Received %d bytes, written %d bytes to PL\n", recieved, written);
				if (written < 0) {
					fprintf(stderr, "ERROR writing to the PL device\n");
					break;
				}
			}
		}
	}
	conn_is_closed_wr: if (arguments.debug_level)
		printf("WR: Connection is closed by the client\n");
	close(fhwr); //we close only what we opened
}

