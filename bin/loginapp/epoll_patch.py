# import sys
from errno import EINTR
import asyncore
import errno
import time

_has_epoll = False
accum_loop_time = 0.0
_begin_time = 0.0
_end_time = 0.0

try:
    import select
    from select import POLLIN, POLLPRI, POLLOUT, POLLERR, POLLHUP, POLLNVAL

    _has_epoll = True
    socket_map = {}
    readwrite = None
    _scheduler = None
    _tasks = None

    pollster = select.epoll()

    _READ_flags = POLLIN | POLLPRI
    _ADDON_flags = POLLERR | POLLHUP | POLLNVAL
except:
    _has_epoll = False


def create_epoll_flags(obj):
    flags = 0
    if obj.readable():
        flags |= _READ_flags
    if obj.writable():
        flags |= POLLOUT
    if flags:
        # Only check for exceptions if object was either readable
        # or writable.
        flags |= _ADDON_flags
    return flags


_except_types = (select.error, IOError)


def poll2(timeout=0.0):
    global _begin_time
    for fd, obj_flags in socket_map.iteritems():
        obj, flags = obj_flags
        new_flags = create_epoll_flags(obj)
        if new_flags != flags:
            pollster.modify(fd, new_flags)
            obj_flags[1] = new_flags

    try:
        r = pollster.poll(timeout)
    except _except_types, err:
        if err[0] != EINTR:
            raise
        r = []
    _begin_time = time.time()
    for fd, flags in r:
        obj_flags = socket_map.get(fd)
        readwrite(obj_flags[0], flags)


def loop(timeout=30.0, use_poll=True, map=None, count=None):
    poll2(timeout)


def add_channel(self, map=None):
    # print "debug add_channel", self, map

    if map is None:
        map = self._map

    flags = create_epoll_flags(self)
    pollster.register(self._fileno, flags)
    map[self._fileno] = [self, flags]


#	print '^^^^^^^^^^^^^^^^'
#	for i, v in map.itervalues():
#		print i, v
#	print '================'

def del_channel(self, map=None):
    # print "debug del_channel", self, map

    fd = self._fileno
    if map is None:
        map = self._map

    #	print '^^^^^^^^^^^^^^^^'
    #	for i, v in map.itervalues():
    #		print i, v
    #	print '================'

    if map.has_key(fd):
        pollster.unregister(fd)
        del map[fd]
    self._fileno = None


#	print '^^^^^^^^^^^^^^^^'
#	for i, v in map.itervalues():
#		print i, v
#	print '================'

def loop_with_timer(timeout=0.1, use_poll=True, map=None, count=None):
    """Start asyncore and scheduler loop.
    Use this as replacement of the original asyncore.loop() function.
    """
    if count is None:
        while (socket_map or _tasks):
            poll2(timeout)
            _scheduler()
    else:
        while (socket_map or _tasks) and count > 0:
            poll2(timeout)
            _scheduler()
            count -= 1


def close_all(map=None, ignore_all=False):
    """Close all scheduled functions and opened sockets."""
    if map is None:
        map = asyncore.socket_map
    for x in map.values():
        try:
            x[0].close()
        except OSError, x:
            if x[0] == errno.EBADF:
                pass
            elif not ignore_all:
                raise
        except (asyncore.ExitNow, KeyboardInterrupt, SystemExit):
            raise
        except:
            if not ignore_all:
                asyncore.socket_map.clear()
                del _tasks[:]
                raise
    map.clear()

    for x in _tasks:
        try:
            if not x.cancelled:
                x.cancel()
        except (asyncore.ExitNow, KeyboardInterrupt, SystemExit):
            raise
        except:
            if not ignore_all:
                del _tasks[:]
                raise
    del _tasks[:]


def install_asyncore():
    if not _has_epoll:
        return

    global readwrite
    readwrite = asyncore.readwrite
    asyncore.loop = loop
    asyncore.poll2 = poll2
    asyncore.socket_map = socket_map
    asyncore.dispatcher.add_channel = add_channel
    asyncore.dispatcher.del_channel = del_channel
    asyncore.close_all = close_all


def _scheduler_with_account():
    import asyncore_with_timer
    global _end_time
    global accum_loop_time
    asyncore_with_timer._scheduler()
    _end_time = time.time()
    accum_loop_time = accum_loop_time + (_end_time - _begin_time)


def install_asyncore_with_timer():
    if not _has_epoll:
        return

    global _scheduler
    global _tasks
    import asyncore_with_timer
    asyncore_with_timer.loop = loop_with_timer
    asyncore_with_timer.close_all = close_all
    _scheduler = _scheduler_with_account  # asyncore_with_timer._scheduler
    _tasks = asyncore_with_timer._tasks
