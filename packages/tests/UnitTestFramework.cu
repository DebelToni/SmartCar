#include <iostream>
int tests_passed = 0;
int tests_failed = 0;
bool check(bool cond) { return cond; }
void assert_true(bool cond, const char* msg) {
    if (cond) {
        std::cout << msg << " passed\n";
        tests_passed++;
    } else {
        std::cout << msg << " failed\n";
        tests_failed++;
    }
}
bool test_equal() { return (2+2) == 4; }
bool test_less() { return (5-3) < 4; }
bool test_vector_size() { return 5 == 5; }
int main() {
    assert_true(test_equal(), "test_equal");
    assert_true(test_less(), "test_less");
    assert_true(test_vector_size(), "test_vector_size");
    std::cout << "Passed: " << tests_passed << " Failed: " << tests_failed << "\n";
    return tests_failed;
}
#include <iostream>
#include <vector>
#include <functional>
int tests_passed=0;
int tests_failed=0;
void run_test(const std::string& name,std::function<bool()> test){
    if(test()){
        std::cout<<name<<" passed\n";
        tests_passed++;
    } else {
        std::cout<<name<<" failed\n";
        tests_failed++;
    }
}
bool test_addition(){
    return (2+2)==4;
}
bool test_subtraction(){
    return (5-3)==2;
}
bool test_vector(){
    std::vector<int> v{1,2,3};
    return v.size()==3;
}
int main(){
    run_test("Addition",test_addition);
    run_test("Subtraction",test_subtraction);
    run_test("VectorSize",test_vector);
    std::cout<<"Passed: "<<tests_passed<<" Failed: "<<tests_failed<<"\n";
    return tests_failed;
}