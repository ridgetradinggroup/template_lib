#include "{{ project_name_underscore }}.h"
#include <iostream>

{{ namespace_open }}

std::string get_message() {
    return "Hello, World!";
}

void print_message() {
    std::cout << get_message() << std::endl;
}

{{ namespace_close }}
