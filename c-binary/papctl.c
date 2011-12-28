#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>

#define _PALM_SOCKET_NAME "palmaudio"

#define _NAME_STRUCT_OFFSET(struct_type, member) ((long) ((unsigned char*) &((struct_type*) 0)->member))

int main(int argc, char **argv) {
	int sock, path_len;

	struct sockaddr_un server;

	if(argc < 2)
		exit(1);

	sock = socket(AF_UNIX, SOCK_STREAM, 0);

	if(sock < 0) {
		perror("opening stream socket");

		exit(1);
	}

	server.sun_family = AF_UNIX;

	server.sun_path[0] = '\0';

	path_len = strlen(_PALM_SOCKET_NAME) + 1;

	strncpy(&server.sun_path[1], _PALM_SOCKET_NAME, path_len);

	if(connect(sock, (struct sockaddr *) &server, _NAME_STRUCT_OFFSET (struct sockaddr_un, sun_path) + path_len) < 0) {
		close(sock);

		perror("connecting stream socket");

		exit(1);
	}

	if(write(sock, argv[1], strlen(argv[1])) < 0) {
		perror("writing to stream socket");

		close(sock);
	}

	close(sock);
}
