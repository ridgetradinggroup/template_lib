#ifndef {{ project_name_upper }}_{{ project_name_upper }}_H
#define {{ project_name_upper }}_{{ project_name_upper }}_H

#include <string>

{{ namespace_open }}
    // Returns the classic hello world message
    std::string get_message();

    // Prints hello message to stdout
    void print_message();
{{ namespace_close }}

#endif // {{ project_name_upper }}_{{ project_name_upper }}_H

