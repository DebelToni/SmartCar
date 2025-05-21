int main() {
    for(int i=1; i<=10; i++) {
        for(int j=0; j<i*10; j++) {
            printf("%d ", j%10);
        }
        printf("\n");
    }
    return 0;
}
