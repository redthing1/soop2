module soop.global;

public import minlog;

struct Context {
    string data_dir;
}
Context g_context;

Logger logger = Logger(Verbosity.info);