#pragma once

#include <string>
#include <iostream>
#include <iomanip>
#include <getopt.h>


#define RESULTS_FOLDER          "./results"


struct lbm_options {
    int platformID;
    int deviceID;
    size_t dim;
    real_t viscosity;
    real_t velocity;
    size_t iterations;
    size_t every;
    std::string vti_path;
    bool store_vti;
    std::string dump_path;
    bool dump_map;
    bool dump_f;

    lbm_options() :
        platformID(-1),
        deviceID(-1),
        dim(8),
        viscosity(0.0089),
        velocity(0.05),
        iterations(10),
        every(1),
        vti_path(RESULTS_FOLDER),
        store_vti(false),
        dump_path(RESULTS_FOLDER),
        dump_map(false),
        dump_f(false)
    {}


    size_t f_dim()   const { return (dim * dim * dim * Q_DIM); }
    size_t u_dim()   const { return (dim * dim * dim * D); }
    size_t rho_dim() const { return (dim * dim * dim); }
    size_t map_dim() const { return (dim * dim * dim); }

    size_t f_size()   const { return f_dim()   * sizeof(real_t); }
    size_t u_size()   const { return u_dim()   * sizeof(real_t); }
    size_t rho_size() const { return rho_dim() * sizeof(real_t); }
    size_t map_size() const { return map_dim() * sizeof(int);    }

    size_t device_memory_size_b() const
    {
        return f_size() * 2 + u_size() + rho_size() + map_size();
    }


    size_t device_memory_size_k() const
    {
        return device_memory_size_b() / (1 << 10);
    }


    size_t device_memory_size_m() const
    {
        return device_memory_size_b() / (1 << 20);
    }


    void print_help()
    {
        std::cout << "-P  --platform            Use the specified platform                \n"
                     "-D  --device              Use the specified device                  \n"
                     "-d  --dim                 Set the lattice cube dimension            \n"
                     "-n  --viscosity           Set the fluid viscosity                   \n"
                     "-u  --velocity            Set the x velocity of the moving wall     \n"
                     "-i  --iterations          Specify the number of iterations          \n"
                     "-e  --every               Save simulation results every N iterations\n"
                     "-v  --vtk_path            Specify where store VTI files             \n"
                     "-p  --dump_path           Specify where store dumps                 \n"
                     "-m  --dump_map            Dump the lattice map                      \n"
                     "-f  --dump_f              Dump the lattice \"f\" for each iteration \n"
                     "-h  --help                Show this help message and exit           \n";
        exit(1);
    }


    void process_args(int argc, char * argv[])
    {
        opterr = 0;

        const char * const short_opts = "P:D:d:n:u:i:e:v:p:mfh";
        const option long_opts[] = {
                {"platform",        required_argument, nullptr, 'P'},
                {"device",          required_argument, nullptr, 'D'},
                {"dim",             required_argument, nullptr, 'd'},
                {"viscosity",       required_argument, nullptr, 'n'},
                {"velocity",        required_argument, nullptr, 'u'},
                {"iterations",      required_argument, nullptr, 'i'},
                {"every",           optional_argument, nullptr, 'e'},
                {"vti_path",        optional_argument, nullptr, 'v'},
                {"dump_path",       optional_argument, nullptr, 'p'},
                {"dump_map",        no_argument,       nullptr, 'm'},
                {"dump_f",          no_argument,       nullptr, 'f'},
                {"help",            no_argument,       nullptr, 'h'},
                {nullptr,           no_argument,       nullptr,   0}
        };

        while (1) {
            const int opt = getopt_long(argc, argv, short_opts, long_opts, nullptr);

            if (opt < 0) break;

            switch (opt) {
                case 'P':
                    if ((platformID = std::stoi(optarg)) < 0) {
                        std::cerr << "Please enter a valid platform" << std::endl;
                        exit(1);
                    }
                    break;
                case 'D':
                    if ((deviceID = std::stoi(optarg)) < 0) {
                        std::cerr << "Please enter a valid device" << std::endl;
                        exit(1);
                    }
                    break;
                case 'd':
                    if ((dim = std::stoi(optarg)) < 0) {
                        std::cerr << "Please enter a valid lattice dimension" << std::endl;
                        exit(1);
                    }
                    break;
                case 'n':
                    if ((viscosity = std::atof(optarg)) < 0) {
                        std::cerr << "Please enter a valid viscosity value" << std::endl;
                        exit(1);
                    }
                    break;
                case 'u':
                    velocity = std::atof(optarg);
                    break;
                case 'i':
                    if ((iterations = std::stoi(optarg)) < 0) {
                        std::cerr << "Please enter a valid number of iterations" << std::endl;
                        exit(1);
                    }
                    break;
                case 'e':
                    if ((every = std::stoi(optarg)) < 0) {
                        std::cerr << "Please enter a valid number for save simulation results every N iterations" << std::endl;
                        exit(1);
                    }
                    break;
                case 'v':
                    vti_path = std::string(optarg);
                    if (vti_path.empty()) {
                        std::cout << "VTI files will be stored here" << std::endl;
                        vti_path = RESULTS_FOLDER;
                    }
                    store_vti = true;
                    break;
                case 'p':
                    dump_path  = std::string(optarg);
                    if (dump_path.empty()) {
                        std::cout << "dump files will be stored here" << std::endl;
                        dump_path = RESULTS_FOLDER;
                    }
                    break;
                case 'm':
                    dump_map = true;
                    break;
                case 'f':
                    dump_f = true;
                    break;
                case 'h':
                case '?':
                default:
                    print_help();
                    break;
            }
        }
    }


    void print_values()
    {
        std::cout << std::boolalpha
                  << "platformID       = " << platformID             << "\n"
                  << "deviceID         = " << deviceID               << "\n"
                  << "dim              = " << dim                    << "\n"
                  << "viscosity        = " << viscosity              << "\n"
                  << "velocity         = " << velocity               << "\n"
                  << "Device Mem. (B)  = " << device_memory_size_b() << "\n"
                  << "Device Mem. (KB) = " << device_memory_size_k() << "\n"
                  << "Device Mem. (MB) = " << device_memory_size_m() << "\n"
                  << "VTI PATH         = " << vti_path               << "\n"
                  << "STORE VTI        = " << store_vti              << "\n"
                  << "DUMP F           = " << dump_f                 << "\n"
                  << "DUMP MAP         = " << dump_map               << "\n";
    }

};