#include <iostream>
#include <vector>
#include <algorithm>
#include <random>
#include <functional>
using Chromosome=std::vector<int>;
int fitness(const Chromosome& c){
    int sum=0;
    for(int gene:c) sum+=gene;
    return sum;
}
Chromosome crossover(const Chromosome& a,const Chromosome& b){
    Chromosome child=a;
    for(size_t i=child.size()/2;i<child.size();++i){
        child[i]=b[i];
    }
    return child;
}
void mutate(Chromosome& c,double rate){
    static std::mt19937 gen(std::random_device{}());
    std::uniform_real_distribution<> dis(0,1);
    std::uniform_int_distribution<> idx(0,c.size()-1);
    for(size_t i=0;i<c.size();++i){
        if(dis(gen)<rate){
            c[idx(gen)]=idx(gen);
        }
    }
}
int main(){
    const int pop_size=100;
    const int gene_count=10;
    const double mutation_rate=0.01;
    std::mt19937 gen(std::random_device{}());
    std::uniform_int_distribution<> gene_val(0,10);
    std::vector<Chromosome> population;
    for(int i=0;i<pop_size;++i){
        Chromosome c;
        for(int j=0;j<gene_count;++j){
            c.push_back(gene_val(gen));
        }
        population.push_back(c);
    }
    for(int generation=0;generation<50;++generation){
        std::sort(population.begin(),population.end(),[](auto&a,auto&b){
            return fitness(a)>fitness(b);
        });
        std::cout<<"Gen "<<generation<<" best "<<fitness(population[0])<<"\n";
        std::vector<Chromosome> newpop;
        for(int i=0;i<pop_size/2;++i){
            Chromosome child=crossover(population[i],population[pop_size-i-1]);
            mutate(child,mutation_rate);
            newpop.push_back(child);
        }
        population=newpop;
    }
    return 0;
}