#include <iostream>
#include <vector>
#include <complex>
#include <cmath>
using cd=std::complex<double>;
void hadamard(std::vector<cd>& s){
    double inv=sqrt(0.5);
    std::vector<cd> copy=s;
    s[0]=inv*(copy[0]+copy[1]);
    s[1]=inv*(copy[0]-copy[1]);
}
void phase(double phi,std::vector<cd>& s){
    s[1]*=std::polar(1.0,phi);
}
int measure(const std::vector<cd>& s){
    double p0=std::norm(s[0]);
    double r=(double)rand()/RAND_MAX;
    return r<p0?0:1;
}
int main(){
    srand(42);
    std::vector<cd> state{1,0};
    for(int i=0;i<5;++i){
        hadamard(state);
        phase(3.1415/4,state);
        int m=measure(state);
        std::cout<<"Iteration "<<i<<" measurement "<<m<<"\n";
        if(m==1){
            state={1,0};
        } else {
            state={0,1};
        }
    }
    return 0;
}