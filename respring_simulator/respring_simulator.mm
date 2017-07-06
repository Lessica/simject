#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <iostream>
#include <string>
#include <array>
#include <regex>

using namespace std;

void printUsage() {
    printf("\nUsage:\n");
    printf("\nRespring the latest booted device:\n\n");
    printf("\trespring_simulator\n");
    printf("\nRespring the booted device with matching type and version:\n\n");
    printf("\trespring_simulator -d \"iPhone 5\" -v 8.1\n");
    printf("\t(Will respring iPhone 5 simulator running iOS 8.1)\n");
    printf("\nRespring the booted device with matching UDID:\n\n");
    printf("\trespring_simulator -i 5AA1C45D-DB69-4C52-A75B-E9BE9C7E7770\n");
    printf("\t(Will respring simulator with UDID 5AA1C45D-DB69-4C52-A75B-E9BE9C7E7770)\n");
    printf("\trespring_simulator all\n");
    printf("\t(Will respring any booted simulator)\n");
    printf("\n");
}

string exec(const char *cmd) {
    array<char, 128> buffer;
    string result;
    shared_ptr<FILE> pipe(popen(cmd, "r"), pclose);
    if (pipe) {
        while (!feof(pipe.get())) {
            if (fgets(buffer.data(), 128, pipe.get()) != NULL)
                result += buffer.data();
        }
    }
    return result;
}

void injectHeader() {
    printf("respring_simulator (C) 2016 Karen Tsai (angelXwind)\n");
    printf("Injecting appropriate dynamic libraries from /opt/simject...\n");
}

void inject(const char *udid, const char *device, BOOL _exit) {
    system([[NSString stringWithFormat:@"xcrun simctl spawn %s launchctl setenv DYLD_INSERT_LIBRARIES /opt/simject/simject.dylib", udid] UTF8String]);
    if (device) {
        printf("Respringing %s (%s) ...\n", udid, device);
    } else {
        printf("Respringing %s ...\n", udid);
    }
    system([[NSString stringWithFormat:@"xcrun simctl spawn %s launchctl stop com.apple.backboardd", udid] UTF8String]);
    if (_exit)
        exit(EXIT_SUCCESS);
}

void injectUDIDs(const char *udid, BOOL all) {
    string bootedDevices = exec("xcrun simctl list devices | grep -E Booted | sed \"s/^[ \\t]*//\"");
    if (!bootedDevices.length()) {
        printf("Error: No such booted devices\n");
        exit(EXIT_FAILURE);
    }
    regex p("(.+) \\(([A-Z0-9\\-]+)\\) \\(Booted\\)");
    smatch m;
    BOOL foundAny = NO;
    injectHeader();
    while (regex_search(bootedDevices, m, p)) {
        const char *bootedDevice = strdup(m[1].str().c_str());
        const char *bootedUDID = strdup(m[2].str().c_str());
        if (all || (udid && strcmp(bootedUDID, udid) == 0)) {
            inject(bootedUDID, bootedDevice, NO);
            foundAny = YES;
        }
        bootedDevices = m.suffix().str();
    }
    if (!foundAny)
        printf("Error: None of booted devices with UDID(s) specified is found\n");
    exit(foundAny ? EXIT_SUCCESS : EXIT_FAILURE);
}

int main(int argc, char *const argv[]) {
    if (argc == 2) {
        if (strcmp(argv[1], "all") == 0) {
            injectUDIDs(NULL, YES);
        } else if (strcmp(argv[1], "help")) {
            printUsage();
            exit(EXIT_SUCCESS);
        }
    }
    int opt;
    char *device = NULL, *version = NULL, *udid = NULL;
    int deviceFlag = 0, versionFlag = 0, udidFlag = 0;
    while ((opt = getopt(argc, argv, "d:v:i:")) != -1) {
        switch (opt) {
            case 'd':
                device = strdup(optarg);
                if (*device == '-') {
                    device = NULL;
                    printf("Error: Device is entered incorrectly\n");
                }
                deviceFlag = 1;
                break;
            case 'v': {
                if (!regex_match(version = strdup(optarg), regex("\\d+\\.\\d+"))) {
                    version = NULL;
                    printf("Error: Version is entered incorrectly\n");
                }
                versionFlag = 1;
                break;
            }
            case 'i':
                if (!regex_match(udid = strdup(optarg), regex("[A-Z0-9\\-]+"))) {
                    udid = NULL;
                    printf("Error: UDID is entered incorrectly\n");
                }
                udidFlag = 1;
                break;
            default:
                printUsage();
                exit(EXIT_FAILURE);
        }
    }
    if (udidFlag || deviceFlag || versionFlag) {
        char buffer[128];
        size_t len = readlink("/var/db/xcode_select_link", buffer, 128);
        if (len && [[[NSBundle bundleWithPath:[NSString stringWithUTF8String:strcat(buffer, "/Applications/Simulator.app/")]] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey] doubleValue] < 800.0) {
            printf("Warning: The selected Xcode version does not support multiple simulators, booting this device could cause the old one to stop (if not the same)");
        }
        if (!(udidFlag != (deviceFlag && versionFlag))) {
            printUsage();
            exit(EXIT_FAILURE);
        }
    }
    if (!udidFlag && !deviceFlag && !versionFlag) {
        injectHeader();
        inject("booted", NULL, YES);
    }
    if (udidFlag) {
        injectUDIDs(udid, NO);
    } else {
        NSString *devicesString = [NSString stringWithUTF8String:exec("xcrun simctl list devices -j").c_str()];
        NSError *error = nil;
        NSDictionary *devices = [NSJSONSerialization JSONObjectWithData:[devicesString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error][@"devices"];
        if (error || devices == nil) {
            printf("Error: Could not list available devices\n");
            exit(EXIT_FAILURE);
        }
        NSArray <NSDictionary *> *runtime = devices[[NSString stringWithFormat:@"iOS %s", version]];
        if (runtime == nil || runtime.count == 0) {
            printf("Error: iOS %s SDK is not installed, or not supported\n", version);
            exit(EXIT_FAILURE);
        }
        for (NSDictionary *entry in runtime) {
            NSString *state = entry[@"state"];
            NSString *name = entry[@"name"];
            NSString *udid = entry[@"udid"];
            if ([name isEqualToString:[NSString stringWithUTF8String:device]]) {
                if (![state isEqualToString:@"Booted"]) {
                    printf("Error: This device is not yet booted up\n");
                    exit(EXIT_FAILURE);
                }
                injectHeader();
                inject([udid UTF8String], [name UTF8String], YES);
            }
        }
    }
    printf("Error: Could not find any booted device with matching information\n");
    exit(EXIT_FAILURE);
}
