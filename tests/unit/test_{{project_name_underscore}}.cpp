#include <gtest/gtest.h>
#include "{{ project_name_underscore }}.h"
#include <sstream>
#include <iostream>
#include <chrono>
#include <thread>
#include <vector>

namespace {

// Test fixture for {{ project_name_underscore }} library tests
class {{ project_name_class }}Test : public ::testing::Test {
protected:
    void SetUp() override {
        // Save original cout buffer
        original_cout_buffer = std::cout.rdbuf();
    }

    void TearDown() override {
        // Restore original cout buffer
        std::cout.rdbuf(original_cout_buffer);
    }

    // Helper to capture stdout
    std::string capture_stdout() {
        std::cout.rdbuf(cout_buffer.rdbuf());
        ridge::print_message();
        std::cout.rdbuf(original_cout_buffer);
        return cout_buffer.str();
    }

    std::stringstream cout_buffer;
    std::streambuf* original_cout_buffer;
};

// Test ridge::get_message() function
TEST_F({{ project_name_class }}Test, GetMessageReturnsCorrectString) {
    std::string message = ridge::get_message();
    EXPECT_EQ(message, "Hello, World!");
}

TEST_F({{ project_name_class }}Test, GetMessageIsNotEmpty) {
    std::string message = ridge::get_message();
    EXPECT_FALSE(message.empty());
}

TEST_F({{ project_name_class }}Test, GetMessageHasCorrectLength) {
    std::string message = ridge::get_message();
    EXPECT_EQ(message.length(), 13); // "Hello, World!" has 13 characters
}

TEST_F({{ project_name_class }}Test, GetMessageStartsWithHello) {
    std::string message = ridge::get_message();
    EXPECT_TRUE(message.find("Hello") == 0);
}

TEST_F({{ project_name_class }}Test, GetMessageEndsWithExclamation) {
    std::string message = ridge::get_message();
    EXPECT_TRUE(message.back() == '!');
}

// Test ridge::print_message() function
TEST_F({{ project_name_class }}Test, PrintMessageOutputsCorrectString) {
    std::string output = capture_stdout();
    EXPECT_EQ(output, "Hello, World!\n");
}

TEST_F({{ project_name_class }}Test, PrintMessageOutputsToStdout) {
    // Redirect stdout to stringstream
    std::stringstream buffer;
    std::cout.rdbuf(buffer.rdbuf());
    
    ridge::print_message();
    
    // Restore stdout
    std::cout.rdbuf(original_cout_buffer);
    
    // Check output
    std::string output = buffer.str();
    EXPECT_FALSE(output.empty());
    EXPECT_TRUE(output.find("Hello, World!") != std::string::npos);
}

TEST_F({{ project_name_class }}Test, PrintMessageEndsWithNewline) {
    std::string output = capture_stdout();
    EXPECT_TRUE(!output.empty() && output.back() == '\n');
}

// Multiple call consistency tests
TEST_F({{ project_name_class }}Test, GetMessageConsistentAcrossMultipleCalls) {
    std::string first_call = ridge::get_message();
    std::string second_call = ridge::get_message();
    std::string third_call = ridge::get_message();
    
    EXPECT_EQ(first_call, second_call);
    EXPECT_EQ(second_call, third_call);
}

// Integration test
TEST_F({{ project_name_class }}Test, PrintMessageUsesGetMessage) {
    std::string expected = ridge::get_message() + "\n";
    std::string actual = capture_stdout();
    EXPECT_EQ(actual, expected);
}

// Performance test (basic)
TEST_F({{ project_name_class }}Test, GetMessagePerformance) {
    auto start = std::chrono::high_resolution_clock::now();
    
    // Call get_message many times
    for (int i = 0; i < 10000; ++i) {
        ridge::get_message();
    }
    
    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    
    // Should complete in reasonable time (less than 1 second)
    EXPECT_LT(duration.count(), 1000);
}

// Thread safety test (basic)
TEST_F({{ project_name_class }}Test, GetMessageThreadSafety) {
    std::vector<std::string> results(4);
    std::vector<std::thread> threads;
    
    // Launch multiple threads calling get_message
    for (int i = 0; i < 4; ++i) {
        threads.emplace_back([&results, i]() {
            results[i] = ridge::get_message();
        });
    }
    
    // Wait for all threads to complete
    for (auto& thread : threads) {
        thread.join();
    }
    
    // All results should be identical
    for (const auto& result : results) {
        EXPECT_EQ(result, "Hello, World!");
    }
}

} // namespace