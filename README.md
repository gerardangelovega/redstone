# Redstone
An in-memory key-value database written in C++ (for now) and built using the Zig Build System for the purposes of learning. Currently a work in progress and is planned to be written in another language because why not.

# Roadmap
The following are features I intend to implement/execute as I continue to work on Redstone in my spare time.
## Implemented
- [x] Request-Response Protocol
- [x] Concurrent IO
- [x] Non-Blocking IO
- [x] Key-Value Store
## Work In Progress
- [ ] Optimized Buffer Implementation
- [x] Optimized Hashtable Implementation
- [x] Data Serialization
- [ ] Indexing
- [ ] Expiration
- [ ] Multi-Threading
## Planned
- [ ] Zig Rewrite
- [ ] Document Project and Code

# Q&A
1. Will this database be ever production ready?
    - Nope, probably never. 
2. What platforms will this database support?
    - This database will only support Linux and other operating systems will not be supported since a good portion of the code relies heavily on Linux System Calls.
3. Why rewrite the database in Zig?
    - So that I can redesign the architecture of the database, reorganize the structure of the code, and be more intimate with the database. Also because I like Zig as a hobby programming language.
4. What problems does this database solve?
    - Nothing, just another toy database.
5. What is the point of this database?
    - The point of this database is simply for me to learn more about the field of Software through a project and so far I've learned a lot about servers, networking, sockets, system calls, data structure, memory management, pointer arithmetic, and much more.
    - This is simply one of the many projects that 'reinvent the wheel to gain an deeper appreciation of the wheel'.
