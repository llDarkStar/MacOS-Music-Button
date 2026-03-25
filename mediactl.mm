#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

typedef NS_ENUM(int, MRMediaRemoteCommand) {
	MRMediaRemoteCommandPlay = 0,
	MRMediaRemoteCommandPause = 1,
	MRMediaRemoteCommandTogglePlayPause = 2,
	MRMediaRemoteCommandNextTrack = 4,
	MRMediaRemoteCommandPreviousTrack = 5
};

typedef void (*MRMediaRemoteGetNowPlayingInfoFunction)(dispatch_queue_t queue, void (^handler)(NSDictionary* information));
typedef Boolean (*MRMediaRemoteSendCommandFunction)(MRMediaRemoteCommand cmd, NSDictionary* userInfo);

static CFBundleRef loadMediaRemoteBundle() {
	CFURLRef ref = (__bridge CFURLRef)[NSURL fileURLWithPath:@"/System/Library/PrivateFrameworks/MediaRemote.framework"];
	return CFBundleCreate(kCFAllocatorDefault, ref);
}

static MRMediaRemoteSendCommandFunction loadSendCommand(CFBundleRef bundle) {
	return (MRMediaRemoteSendCommandFunction)CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteSendCommand"));
}

static MRMediaRemoteGetNowPlayingInfoFunction loadGetInfo(CFBundleRef bundle) {
	return (MRMediaRemoteGetNowPlayingInfoFunction)CFBundleGetFunctionPointerForName(bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));
}

static NSString* json(NSDictionary* obj) {
	NSData* data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
	return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static void printJSON(NSDictionary* obj) {
	NSString* s = json(obj);
	printf("%s\n", [s UTF8String]);
	fflush(stdout);
}

static double parseTimeoutMs(int argc, char** argv, double defMs) {
	for (int i = 1; i < argc - 1; i++) {
		if (strcmp(argv[i], "--timeout-ms") == 0) {
			char* end = NULL;
			double v = strtod(argv[i + 1], &end);
			if (end && *end == '\0' && v > 0) return v;
		}
	}
	return defMs;
}

static NSString* parseCmd(int argc, char** argv) {
	for (int i = 1; i < argc; i++) {
		if (argv[i][0] == '-') continue;
		return [NSString stringWithUTF8String:argv[i]];
	}
	return @"";
}

int main(int argc, char** argv) {
	@autoreleasepool {
		NSString* cmd = parseCmd(argc, argv);
		double timeoutMs = parseTimeoutMs(argc, argv, 1200);

		if (cmd.length == 0) {
			printJSON(@{@"ok": @NO, @"error": @"no_command"});
			return 2;
		}

		// Инициализация приложения - ОЧЕНЬ ВАЖНО
		NSApplicationLoad();
		[NSApplication sharedApplication];
		
		// Нужно создать видимое окно для доступа к MediaRemote
		NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1, 1)
			styleMask:NSWindowStyleMaskTitled
			backing:NSBackingStoreBuffered
			defer:NO];
		[window setLevel:NSFloatingWindowLevel];
		(void)window;

		CFBundleRef bundle = loadMediaRemoteBundle();
		if (!bundle) {
			printJSON(@{@"ok": @NO, @"error": @"bundle_load_failed"});
			return 3;
		}

		MRMediaRemoteSendCommandFunction sendCmd = loadSendCommand(bundle);
		MRMediaRemoteGetNowPlayingInfoFunction getInfo = loadGetInfo(bundle);

		if (!sendCmd || !getInfo) {
			printJSON(@{@"ok": @NO, @"error": @"symbols_not_found"});
			return 4;
		}

		dispatch_semaphore_t sema = dispatch_semaphore_create(0);
		__block NSDictionary* infoOut = nil;
		__block BOOL infoReceived = NO;

		getInfo(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^(NSDictionary* information) {
			infoOut = information ?: @{};
			infoReceived = YES;
			dispatch_semaphore_signal(sema);
		});

		dispatch_time_t deadline = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeoutMs * 1000000.0));
		dispatch_semaphore_wait(sema, deadline);

		// Pause - проверяем результат
		if ([cmd isEqualToString:@"pause"]) {
			BOOL result = sendCmd(MRMediaRemoteCommandPause, nil);
			if (result) {
				printJSON(@{@"ok": @YES, @"status": @"paused"});
				return 0;
			} else {
				printJSON(@{@"ok": @NO, @"error": @"pause_command_failed"});
				return 1;
			}
		}

		// Play - проверяем результат
		if ([cmd isEqualToString:@"play"]) {
			BOOL result = sendCmd(MRMediaRemoteCommandPlay, nil);
			if (result) {
				printJSON(@{@"ok": @YES, @"status": @"playing"});
				return 0;
			} else {
				printJSON(@{@"ok": @NO, @"error": @"play_command_failed"});
				return 1;
			}
		}

		// Toggle - проверяем результат
		if ([cmd isEqualToString:@"toggle"]) {
			BOOL result = sendCmd(MRMediaRemoteCommandTogglePlayPause, nil);
			if (result) {
				printJSON(@{@"ok": @YES, @"status": @"toggled"});
				return 0;
			} else {
				printJSON(@{@"ok": @NO, @"error": @"toggle_command_failed"});
				return 1;
			}
		}

		// Info - с проверкой timeout
		if ([cmd isEqualToString:@"info"]) {
			if (!infoReceived) {
				printJSON(@{@"ok": @NO, @"error": @"info_timeout"});
				return 5;
			}

			NSNumber* rate = infoOut[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"];
			BOOL playing = rate ? ([rate doubleValue] > 0.0) : NO;

			id title = infoOut[@"kMRMediaRemoteNowPlayingInfoTitle"] ?: [NSNull null];
			id artist = infoOut[@"kMRMediaRemoteNowPlayingInfoArtist"] ?: [NSNull null];

			printJSON(@{
				@"ok": @YES,
				@"playing": @(playing),
				@"title": title,
				@"artist": artist
			});
			return 0;
		}

		printJSON(@{@"ok": @NO, @"error": @"unknown_command"});
		return 2;
	}
}
