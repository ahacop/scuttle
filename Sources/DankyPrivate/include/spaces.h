#pragma once
#import <Foundation/Foundation.h>

// Automatic Space lifecycle requires macOS 27 or later. Earlier systems can change WindowServer's
// Space list without updating Dock; callers must use existing desktops instead.
bool danky_can_manage_spaces(void);

// Creates one user Space on the display through the bridged SLSBridgedSpaceCreateOperation.
// Returns 0 without mutation on unsupported systems, or with the failure reason on stderr.
uint64_t danky_create_space(CFStringRef displayUUID);

// Removes a Space through the bridged SLSBridgedSpaceDestroyOperation. Its windows go to the display's current
// Space. Asynchronous: returns once the request is sent; false without mutation on unsupported systems,
// or with the failure reason on stderr if the request could not be sent.
bool danky_destroy_space(uint64_t spaceID);
