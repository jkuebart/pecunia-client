/**
 * Copyright (c) 2011, 2014, Pecunia Project. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; version 2 of the
 * License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301  USA
 */

#import <sys/sysctl.h>

#import "MessageLog.h"

#import "ZipFile.h"
#import "ZipWriteStream.h"
#import "ZipException.h"

#import "LaunchParameters.h"
#import "ResultWindowController.h"


@interface MessageLog () {
    int          logLevel;        // One of the CocoaLumberjack log levels. Only used for the regular logger.
    DDFileLogger *fileLogger;     // The regular file logger.
    DDFileLogger *comTraceLogger; // The communication trace logger.
}
@end

@implementation MessageLog

@synthesize resultWindow;

- (id)init {
    self = [super init];
    if (self != nil) {
        // Default log level is info, unless we are debugging or got a custom log level.
        // As long as we have this and MessageLog.swift separated we also have to set the log level there.
#ifdef DEBUG
        // Logging to console only for debug builds. Otherwise use the log file only.
        logLevel = DDLogLevelDebug;
        [DDLog addLogger: DDTTYLogger.sharedInstance];
        DDTTYLogger.sharedInstance.colorsEnabled = YES;

        // Swift.
        DDLog.logLevel = DDLogLevelDebug;
#else
        logLevel = DDLogLevelInfo;
        DDLog.logLevel = DDLogLevelInfo;
#endif

        // The file logger is always active.
        fileLogger = [[DDFileLogger alloc] init];
        fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
        [DDLog addLogger: fileLogger];

        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        [defaults addObserver: self forKeyPath: @"logLevel" options: NSKeyValueObservingOptionInitial context: nil];

        fileLogger.doNotReuseLogFiles = YES; // Start with a new log file at each application launch.

        self.resultWindow = [[ResultWindowController alloc] init];
        [self cleanUp]; // In case we were not shutdown properly on last run.
    }
    return self;
}

- (void)dealloc
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults removeObserver: self forKeyPath: @"logLevel"];
}

- (void)observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary<NSString *,id> *)change context: (void *)context {
    if ([keyPath isEqualToString: @"logLevel"]) {
        NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
        NSInteger level = [defaults integerForKey: @"logLevel"];
        switch (level) {
            case 0:
                logLevel = DDLogLevelError;
                DDLog.logLevel = DDLogLevelError;
                break;

            case 1:
                logLevel = DDLogLevelWarning;
                DDLog.logLevel = DDLogLevelWarning;
                break;

            case 3:
                logLevel = DDLogLevelDebug;
                DDLog.logLevel = DDLogLevelDebug;
                break;

            case 4:
                logLevel = DDLogLevelVerbose;
                DDLog.logLevel = DDLogLevelVerbose;
                break;

            default:
                logLevel = DDLogLevelInfo;
                DDLog.logLevel = DDLogLevelInfo;
                break;
        }
        return;
    }
    [super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
}

/**
 * Internal helper method for prettyPrintServerMessage.
 */
+ (NSString *)doPrettyPrint: (NSString *)text {
    if ([text hasPrefix: @"<"]) {
        NSError       *error;
        NSXMLDocument *document = [[NSXMLDocument alloc] initWithXMLString: text
                                                                   options: NSXMLNodePreserveAll
                                                                     error: &error];
        if (error == nil) {
            text = [document XMLStringWithOptions: NSXMLNodePrettyPrint];
        }

        return [NSString stringWithFormat: @"{\n%@\n}", text];
    }

    NSArray *parts = [text componentsSeparatedByString: @"'"];
    if (parts.count == 1) {
        return text;
    }
    NSString *combined = [parts componentsJoinedByString: @"\n  "];
    return [NSString stringWithFormat: @"{\n  %@\n}", [combined substringToIndex: combined.length - 3]];
}

/**
 * Server messages can have different formats and this functions tries to pretty print in a human
 * readable format.
 */
+ (NSString *)prettyPrintServerMessage: (NSString *)text {
    // For now only format plain xml log messages (usually commands) whose format isn't important for error analysis,
    // but which profit from better readablility. All other messages stay as they are.
    if ([text hasPrefix: @"<"]) {
        NSError       *error;
        NSXMLDocument *document = [[NSXMLDocument alloc] initWithXMLString: text
                                                                   options: NSXMLNodePreserveAll
                                                                     error: &error];
        if (error == nil) {
            text = [document XMLStringWithOptions: NSXMLNodePrettyPrint];
        }

        return [NSString stringWithFormat: @"{\n%@\n}", text];
    }

    return text;
}

+ (NSString *)getStringInfoFor: (const char *)name {
    NSString *result = @"Unknown";

    size_t len = 0;
    sysctlbyname(name, NULL, &len, NULL, 0);

    if (len > 0) {
        char *value = malloc(len * sizeof(char));
        sysctlbyname(name, value, &len, NULL, 0);
        result = [NSString stringWithUTF8String: value];
        free(value);
    }

    return result;
}

+ (NSNumber *)getNumberInfoFor: (const char *)name {
    size_t len = 0;
    sysctlbyname(name, NULL, &len, NULL, 0);

    switch (len) {
        case 4: {
            int value;
            sysctlbyname(name, &value, &len, NULL, 0);
            return [NSNumber numberWithInt: value];
        }

        case 8: {
            int64_t value = 0;
            sysctlbyname(name, &value, &len, NULL, 0);
            return [NSNumber numberWithInteger: value];
        }

        default:
            return [NSNumber numberWithInt: 0];
    }
}

+ (MessageLog *)log {
    static MessageLog *_messageLog;

    if (_messageLog == nil) {
        _messageLog = [[MessageLog alloc] init];

        // Log some important information. This goes to the newly created log file.
        LogInfo(@"Starting up application");

        NSProcessInfo *info = NSProcessInfo.processInfo;
        info.automaticTerminationSupportEnabled = NO;

        LogInfo(@"Arguments: %@", info.arguments);

        NSBundle *mainBundle = [NSBundle mainBundle];
        LogInfo(@"Pecunia version: %@", [mainBundle objectForInfoDictionaryKey: @"CFBundleShortVersionString"]);
        LogInfo(@"Pecunia build version: %@", [mainBundle objectForInfoDictionaryKey: @"CFBundleVersion"]);

        LogInfo(@"Machine + OS: %@, %@", [MessageLog getStringInfoFor: "hw.model"], info.operatingSystemVersionString);
        LogInfo(@"Mem size: %.01fGB", [MessageLog getNumberInfoFor: "hw.memsize"].doubleValue / 1024 / 1024 / 1024);
        LogInfo(@"CPU : %@", [MessageLog getStringInfoFor: "machdep.cpu.brand_string"]);

        LogInfo(@"Process environment: %@", info.environment);

    }
    return _messageLog;
}

+ (MessageLog*)getLog {
    return [self log];
}

- (void)logError: (NSString *)format file: (const char *)file function: (const char *)function line: (int)line, ...{
    self.hasError = YES;
    if ((logLevel & DDLogFlagError) != 0) {
        va_list args;
        va_start(args, line);

        [DDLog   log: NO
               level: logLevel
                flag: DDLogFlagError
             context: 0
                file: file
            function: function
                line: line
                 tag:  nil
              format: [NSString stringWithFormat: @"[Error] %@", format]
                args: args];
    }
}

- (void)logError1: (NSString *)format file: (const char *)file function: (const char *)function line: (int)line arguments:(va_list)args{
    [ self logError:format file:file function:function line:line];
    [self.resultWindow addMessage: format];
}


- (void)logWarning: (NSString *)format file: (const char *)file function: (const char *)function line: (int)line, ...{
    if ((logLevel & DDLogFlagWarning) != 0) {
        va_list args;
        va_start(args, line);

        [DDLog   log: YES
               level: logLevel
                flag: DDLogFlagWarning
             context: 0
                file: file
            function: function
                line: line
                 tag:  nil
              format: [NSString stringWithFormat: @"[Warning] %@", format]
                args: args];
    }
}

- (void)logInfo: (NSString *)format file: (const char *)file function: (const char *)function line: (int)line, ...{
    if ((logLevel & DDLogFlagInfo) != 0) {
        va_list args;
        va_start(args, line);

        [DDLog   log: YES
               level: logLevel
                flag: DDLogFlagInfo
             context: 0
                file: file
            function: function
                line: line
                 tag:  nil
              format: [NSString stringWithFormat: @"[Info] %@", format]
                args: args];
    }
}

- (void)logDebug: (NSString *)format file: (const char *)file function: (const char *)function line: (int)line, ...{
    if ((logLevel & DDLogFlagDebug) != 0) {
        va_list args;
        va_start(args, line);

        [DDLog   log: YES
               level: logLevel
                flag: DDLogFlagDebug
             context: 0
                file: file
            function: function
                line: line
                 tag:  nil
              format: [NSString stringWithFormat: @"[Debug] %@", format]
                args: args];
    }
}

- (void)logDebug: (NSString *)format, ...{
    if ((logLevel & DDLogFlagDebug) != 0) {
        va_list args;
        va_start(args, format);

        [DDLog   log: YES
               level: logLevel
                flag: DDLogFlagDebug
             context: 0
                file: ""
            function: ""
                line: 0
                 tag:  nil
              format: [NSString stringWithFormat: @"[Debug] %@", format]
                args: args];
    }
}

- (void)logVerbose: (NSString *)format file: (const char *)file function: (const char *)function line: (int)line, ...{
    if ((logLevel & DDLogFlagVerbose) != 0) {
        va_list args;
        va_start(args, line);

        [DDLog   log: YES
               level: logLevel
                flag: DDLogFlagVerbose
             context: 0
                file: file
            function: function
                line: line
                 tag:  nil
              format: [NSString stringWithFormat: @"[Verbose] %@", format]
                args: args];
    }
}

/**
 * An attempt is made to compress the source file and add the created zip (the target file) to the given items array.
 * If that for any reason fails the source file is added to the items instead.
 */
- (void)compressFileAndAndAddToItems: (NSMutableArray *)items
                          sourceFile: (NSURL *)source
                          targetFile: (NSURL *)target {
    BOOL savedAsZip = NO;

    @try {
        ZipFile *zipFile = [[ZipFile alloc] initWithFileName: target.path
                                                        mode: ZipFileModeCreate];
        ZipWriteStream *stream = [zipFile writeFileInZipWithName: [source.path lastPathComponent]
                                                compressionLevel: ZipCompressionLevelBest];
        NSData *logData = [NSData dataWithContentsOfURL: source];
        [stream writeData: logData];
        [stream finishedWriting];
        [zipFile close];

        [items addObject: target];
        savedAsZip = YES;
    }
    @catch (NSException *e) {
        LogError(@"Fehler beim packen des Logs (%@). Fehler: %@", source, e);
    }

    if (!savedAsZip) {
        [items addObject: source];
    }
}

/*
 * Sends the current log via mail to the Pecunia support. If there's a communication trace this is sent too.
 */
- (void)sendLog {
    [DDLog flushLog];

    // The standard log.
    NSArray *filePaths = [fileLogger.logFileManager sortedLogFilePaths];
    NSURL   *logURL = [NSURL fileURLWithPath: filePaths[0]];

    NSMutableArray *mailItems = [NSMutableArray array];
    if (logURL != nil) {
        // We use fixed zip file names by intention, to avoid polluting the log folder with many zip files.
        NSString *zip = [[fileLogger.logFileManager logsDirectory] stringByAppendingPathComponent: @"Pecunia Log.zip"];
        [self compressFileAndAndAddToItems: mailItems sourceFile: logURL targetFile: [NSURL fileURLWithPath: zip]];
    }

    // It's a weird oversight that there's no unified way of sending a mail to a given address with an attachment.
    // That holds true at least until 10.8 where we finally have sharing services for that.
    if (floor(NSAppKitVersionNumber) < NSAppKitVersionNumber10_8) {
        // The least comfortable way.
        NSString *mailtoLink = [NSString stringWithFormat: @"mailto:support@pecuniabanking.de?subject=%@&body=%@%@",
                                NSLocalizedString(@"AP123", nil),
                                NSLocalizedString(@"AP121", nil),
                                NSLocalizedString(@"AP122", nil)];
        NSURL *url = [NSURL URLWithString: (NSString *)
                      CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)mailtoLink,
                                                                                NULL, NULL, kCFStringEncodingUTF8))];

        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: mailItems];
        [[NSWorkspace sharedWorkspace] openURL: url];
    } else {
        NSAttributedString *textAttributedString = [[NSAttributedString alloc] initWithString: NSLocalizedString(@"AP121", nil)];

        NSSharingService *mailShare = [NSSharingService sharingServiceNamed: NSSharingServiceNameComposeEmail];
        [mailItems insertObject: textAttributedString atIndex: 0];
        if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_8) {
            // Mavericks and up. The best solution.
            mailShare.subject = NSLocalizedString(@"AP123", nil);
            mailShare.recipients = @[@"support@pecuniabanking.de"];
        } else {
            // Cannot set a mail subject or receiver before OS X 10.9 <sigh>.
            [mailItems insertObject: NSLocalizedString(@"AP124", nil) atIndex: 0];
        }
        [mailShare performWithItems: mailItems];
    }
}

- (void)showLog {
    [DDLog flushLog];

    // The standard log.
    NSArray *filePaths = [fileLogger.logFileManager sortedLogFilePaths];
    [NSWorkspace.sharedWorkspace openFile: filePaths[0]];
}

- (void)openLogFolder {
    NSArray *filePaths = [fileLogger.logFileManager sortedLogFilePaths];
    NSURL   *logURL = [NSURL fileURLWithPath: filePaths[0]];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: @[logURL]];
}

- (void)cleanUp {
    // Clean up the log folder. Remove any com trace and zip file there.
    NSFileManager *manager = NSFileManager.defaultManager;

    NSString    *logFolder = fileLogger.logFileManager.logsDirectory;
    NSArray     *allFiles = [manager contentsOfDirectoryAtPath: logFolder error: nil];
    NSPredicate *filter = [NSPredicate predicateWithFormat: @"self ENDSWITH '.zip'"];
    NSArray     *filteredFiles = [allFiles filteredArrayUsingPredicate: filter];

    for (NSString *file in filteredFiles) {
        NSError *error = nil;
        [manager removeItemAtPath: [logFolder stringByAppendingPathComponent: file] error: &error];
        if (error != nil) {
            LogError(@"Datei konnte nicht gelöscht werden. Ursache: %@", error);
        }
    }
    filter = [NSPredicate predicateWithFormat: @"self CONTAINS 'com trace'"];
    filteredFiles = [allFiles filteredArrayUsingPredicate: filter];

    for (NSString *file in filteredFiles) {
        NSError *error = nil;
        [manager removeItemAtPath: [logFolder stringByAppendingPathComponent: file] error: &error];
        if (error != nil) {
            LogError(@"Datei konnte nicht gelöscht werden. Ursache: %@", error);
        }
    }
}

@end
