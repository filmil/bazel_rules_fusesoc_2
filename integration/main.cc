#include "Vblinky.h"
#include "verilated.h"

#include <iostream>
#include <memory>

vluint64_t main_time = 0;
double sc_time_stamp() { return main_time; }

int main(int argc, char** argv) {
    std::cout << "Hello world!" << std::endl;

    VerilatedContext ctx;
    Vblinky top(&ctx);

    top.clk = false;
    const int half_period = 2500;
    while (main_time < 100000) {
        std::cout << "main time: " << main_time << std::endl;
        // Toggle clock
        if ((main_time % half_period) == 0) {
            top.clk = !top.clk;
        }

        top.eval();
        main_time++;
    }

    top.final();

    return 0;
}
