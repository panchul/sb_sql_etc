#
# $ pg_config --libdir
#  /usr/lib/x86_64-linux-gnu
#
# $ pg_config --includedir
#  /usr/include/postgresql

all: a.out

a.out: testlibpq3.c
	g++ testlibpq3.c -I/usr/include/postgresql -L/usr/lib/x86_64-linux-gnu -lpq

