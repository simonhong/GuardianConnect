//
//  GRDConnectDevice.m
//  GuardianConnect
//
//  Created by Constantin Jacob on 08.02.23.
//  Copyright © 2023 Sudo Security Group Inc. All rights reserved.
//

#import "GRDConnectDevice.h"

@implementation GRDConnectDevice

- (instancetype)initFromDictionary:(NSDictionary *)deviceDictionary {
	self = [super init];
	if (self) {
		self.nickname = [deviceDictionary objectForKey:kGuardianConnectDeviceNicknameKey];
		self.uuid = [deviceDictionary objectForKey:kGuardianConnectDeviceUUIDKey];
		self.peToken = [deviceDictionary objectForKey:kGuardianConnectDevicePETokenKey];
		
		NSNumber *petExpires = [deviceDictionary objectForKey:kGuardianConnectDevicePETExpiresKey];
		self.petExpires = [NSDate dateWithTimeIntervalSince1970:[petExpires integerValue]];
		
		NSNumber *createdAtUnix = [deviceDictionary objectForKey:kGuardianConnectDeviceCreatedAtKey];
		self.createdAt = [NSDate dateWithTimeIntervalSince1970:[createdAtUnix integerValue]];
	}
	
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = [super init];
	if (self) {
		self.nickname = [coder decodeObjectForKey:kGuardianConnectDeviceNicknameKey];
		self.uuid = [coder decodeObjectForKey:kGuardianConnectDeviceUUIDKey];
		
		NSNumber *petExpiresUnix = [coder decodeObjectForKey:kGuardianConnectDevicePETExpiresKey];
		self.petExpires = [NSDate dateWithTimeIntervalSince1970:[petExpiresUnix integerValue]];
		
		NSNumber *createdAtUnix = [coder decodeObjectForKey:kGuardianConnectDeviceCreatedAtKey];
		self.createdAt = [NSDate dateWithTimeIntervalSince1970:[createdAtUnix integerValue]];
		
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:self.nickname forKey:kGuardianConnectDeviceNicknameKey];
	[coder encodeObject:self.uuid forKey:kGuardianConnectDeviceUUIDKey];
	
	NSNumber *petExpiresUnix = [NSNumber numberWithInteger:[self.petExpires timeIntervalSince1970]];
	[coder encodeObject:petExpiresUnix forKey:kGuardianConnectDevicePETExpiresKey];
	
	NSNumber *createdAtUnix = [NSNumber numberWithInteger:[self.createdAt timeIntervalSince1970]];
	[coder encodeObject:createdAtUnix forKey:kGuardianConnectDeviceCreatedAtKey];
}

+ (BOOL)supportsSecureCoding {
	return YES;
}

+ (void)currentDeviceWithCompletion:(void (^)(GRDConnectDevice * _Nullable, NSError * _Nullable))completion {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSData *deviceDict = [defaults objectForKey:kGuardianConnectDevice];
	if (deviceDict == nil) {
		if (completion) completion(nil, nil);
		return;
	}
	
	NSError *unarchiveErr;
	GRDConnectDevice *device = [NSKeyedUnarchiver unarchivedObjectOfClass:[GRDConnectDevice class] fromData:deviceDict error:&unarchiveErr];
	
	if (completion) completion(device, unarchiveErr);
}

- (BOOL)loadFromKeychain {
	BOOL success = NO;
	NSString *pet = [GRDKeychain getPasswordStringForAccount:kKeychainStr_PEToken];
	if (pet != nil) {
		success = YES;
		self.peToken = pet;
	}
	
	return success;
}

- (NSError *)store {
	self.peToken = nil;
	
	NSError *archiveErr;
	NSData *deviceData = [NSKeyedArchiver archivedDataWithRootObject:self requiringSecureCoding:YES error:&archiveErr];
	if (archiveErr != nil) {
		return archiveErr;
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:deviceData forKey:kGuardianConnectDevice];
	
	return nil;
}


# pragma mark - API Wrappers

+ (void)addConnectDeviceWithPEToken:(NSString *)peToken nickname:(NSString *)nickname acceptedTOS:(BOOL)acceptedTOS andCompletion:(void (^)(GRDConnectDevice * _Nullable, NSString * _Nullable))completion {
	[[GRDHousekeepingAPI new] addConnectDeviceWith:peToken nickname:nickname acceptedTOS:acceptedTOS andCompletion:^(NSDictionary * _Nullable deviceDetails, NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(nil, errorMessage);
			return;
		}
		
		GRDConnectDevice *newDevice = [[GRDConnectDevice alloc] initFromDictionary:deviceDetails];
		if (completion) completion(newDevice, nil);
		return;
	}];
}

- (void)updateConnectDeviceWithPEToken:(NSString *)peToken nickname:(NSString *)newNickname andCompletion:(void (^)(GRDConnectDevice * _Nullable, NSString * _Nullable))completion {
	[[GRDHousekeepingAPI new] updateConnectDevice:self.uuid withPEToken:peToken nickname:newNickname andCompletion:^(NSDictionary * _Nullable deviceDetails, NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(nil, errorMessage);
			return;
		}
		
		GRDConnectDevice *updatedDevice = [[GRDConnectDevice alloc] initFromDictionary:deviceDetails];
		if (completion) completion(updatedDevice, nil);
		return;
	}];
}

+ (void)listConnectDevicesForPEToken:(NSString *)peToken withCompletion:(void (^)(NSArray<GRDConnectDevice *> * _Nullable, NSString * _Nullable))completion {
	[[GRDHousekeepingAPI new] listConnectDevicesFor:peToken withCompletion:^(NSArray * _Nullable devices, NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(nil, errorMessage);
			return;
		}
		
		NSMutableArray *parsedDevices = [NSMutableArray new];
		for (NSDictionary *deviceDict in devices) {
			GRDConnectDevice *device = [[GRDConnectDevice alloc] initFromDictionary:deviceDict];
			[parsedDevices addObject:device];
		}
		
		if (completion) completion(parsedDevices, nil);
		return;
	}];
}

- (void)deleteDeviceWithPEToken:(NSString *)peToken andCompletion:(void (^)(NSString * _Nullable))completion {
	[[GRDHousekeepingAPI new] deleteConnectDevice:self.uuid withPEToken:peToken andCompletion:^(NSString * _Nullable errorMessage) {
		if (completion) completion(errorMessage);
		return;
	}];
}

- (void)validateConnectDeviceWithDevicePEToken:(NSString *)peToken andCompletion:(void (^)(GRDConnectDevice * _Nullable, NSString * _Nullable))completion {
	[[GRDHousekeepingAPI new] validateConnectDevicePEToken:self.peToken andCompletion:^(NSDictionary * _Nullable deviceDetails, NSString * _Nullable errorMessage) {
		if (errorMessage != nil) {
			if (completion) completion(nil, errorMessage);
			return;
		}
		
		GRDConnectDevice *newDevice = [[GRDConnectDevice alloc] initFromDictionary:deviceDetails];
		if (completion) completion(newDevice, nil);
		return;
	}];
}

@end
