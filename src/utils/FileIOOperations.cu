#include <iostream>
#include <fstream>
#include <string>
#include <vector>
int countWords(const std::string& s){
    int count=0;
    bool inWord=false;
    for(char c:s){
        if(!isspace(c)&&!inWord){
            inWord=true;
            count++;
        } else if(isspace(c)){
            inWord=false;
        }
    }
    return count;
}
int main(){
    std::ofstream ofs("output.txt");
    for(int i=0;i<10;++i){
        ofs<<"Line "<<i<<"\n";
    }
    ofs.close();
    std::ifstream ifs("output.txt");
    std::vector<std::string> lines;
    std::string line;
    while(std::getline(ifs,line)){
        lines.push_back(line);
    }
    ifs.close();
    std::cout<<"Read "<<lines.size()<<" lines"<<"\n";
    for(auto& l:lines){
        std::cout<<l<<"\n";
    }
    std::ofstream ofs2("reversed.txt");
    for(auto it=lines.rbegin();it!=lines.rend();++it){
        ofs2<<*it<<"\n";
    }
    ofs2.close();
    std::cout<<"Reversed written"<<"\n";
    for(auto& l:lines){
        std::cout<<countWords(l)<<" words in \""<<l<<"\"\n";
    }
    return 0;
}