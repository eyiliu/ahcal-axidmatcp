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

#include <chrono>
#include <thread>
#include <vector>

#include <cstddef>
#include <cstdint>


using ::std::int8_t;
using ::std::int16_t;
using ::std::int32_t;
using ::std::int64_t;

using ::std::uint8_t;
using ::std::uint16_t;
using ::std::uint32_t;
using ::std::uint64_t;

using ::std::size_t;

using namespace std::chrono_literals;

static sig_atomic_t g_done = 0;
int main(int argc, char **argv) {
  signal(SIGINT, [](int){g_done+=1;});


  std::vector<uint32_t>  rd_data(1024, 0);
  std::vector<uint32_t>  wr_data(1024);
  for(uint32_t i = 0; i<wr_data.size(); i++ ){
    wr_data[i] = i;
  }


  unsigned char *pl_rd_buf = reinterpret_cast<unsigned char *>(&rd_data[0]);
  unsigned char *pl_wr_buf = reinterpret_cast<unsigned char *>(&wr_data[0]);
  

  int fhwr = open(WR_PATH, O_WRONLY);
  int fhrd = open(RD_PATH, O_RDONLY | O_NONBLOCK);

  int n_wr = write(fhwr, pl_wr_buf, wr_data.size()*4);

  uint32_t n_rd_total = 0;
  while(!g_done){

    std::this_thread::sleep_for(300ms);
    int n_rd = read(fhrd, pl_rd_buf, rd_data.size()*4);
    
    if( n_rd == 0){
      continue;
    }
    else if (n_rd < 0) {
      if (errno == EAGAIN)
	continue; //no problem, just no data
      fprintf(stderr, "ERROR on reading from axidmard, errno=%d\n", errno);
      return 1;
    }
    n_rd_total += n_rd;
    fprintf(stdout, "n_rd_total: %d ,   n_rd: %d \n", n_rd_total, n_rd );
  }

  
  for(uint32_t i = 0; i<rd_data.size(); i++ ){
    if(i%10 == 0)
      fprintf(stdout, "\n");
    fprintf(stdout, "%d:%d | ", i, rd_data[i] );
  }
  fprintf(stdout, "\n");
  
  return 0;
}