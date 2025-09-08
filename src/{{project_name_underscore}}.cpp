#include "{{ project_name_underscore }}.h"
#include <iostream>

namespace ridge {

std::string get_message() {
    return "Hello, World!";
}

void print_message() {
    std::cout << get_message() << std::endl;
}

} // namespace ridge
