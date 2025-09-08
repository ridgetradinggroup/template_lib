#include <{{ project_name_underscore }}.h>
#include <iostream>

int main()
{
	std::cout << "✓ Downstream test executable runs successfully!" << std::endl;
	std::cout << "✓ Successfully linked with {{ project_name }}" << std::endl;

	std::cout << "The App using {{ project_name }}" << std::endl;
	ridge::print_message();

	return 0;
}
