#include <iostream>
#include <cmath>
#include <vector>
struct Vec3{
    double x,y,z;
    Vec3 operator+(const Vec3&o)const{return{ x+o.x,y+o.y,z+o.z};}
    Vec3 operator-(const Vec3&o)const{return{ x-o.x,y-o.y,z-o.z};}
    Vec3 operator*(double s)const{return{ x*s,y*s,z*s};}
    Vec3 normalize()const{
        double m=std::sqrt(x*x+y*y+z*z);
        return{ x/m,y/m,z/m};
    }
};
double intersectSphere(const Vec3&orig,const Vec3&dir){
    Vec3 center{0,0,5};
    double radius=1;
    Vec3 oc=orig-center;
    double b=2*(oc.x*dir.x+oc.y*dir.y+oc.z*dir.z);
    double c=(oc.x*oc.x+oc.y*oc.y+oc.z*oc.z)-radius*radius;
    double disc=b*b-4*c;
    if(disc<0) return -1;
    return (-b-std::sqrt(disc))/2;
}
int main(){
    const int width=80;
    const int height=40;
    Vec3 origin{0,0,0};
    for(int y=0;y<height;++y){
        for(int x=0;x<width;++x){
            double nx=(x-width/2.0)/width;
            double ny=(y-height/2.0)/height;
            Vec3 dir{nx,ny,1};
            dir=dir.normalize();
            double t=intersectSphere(origin,dir);
            if(t>0){
                std::cout<<"*";
            } else {
                std::cout<<" ";
            }
        }
        std::cout<<"\n";
    }
    return 0;
}