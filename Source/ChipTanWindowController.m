/**
 * Copyright (c) 2011, 2013, Pecunia Project. All rights reserved.
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

#import "ChipTanWindowController.h"
#import "FlickerView.h"

#define FREQ_MAX             70
#define FREQ_MIN             10
#define FREQ_DEFAULT         20

#define FLICKER_SIZE_MIN     20
#define FLICKER_SIZE_MAX     60
#define FLICKER_SIZE_DEFAULT 45

@implementation ChipTanWindowController


@synthesize tan;
@synthesize userMessage;

- (id)initWithCode: (NSString *)flickerCode message: (NSString *)msg userName: (NSString *)name;
{
    NSString   *code;
    NSUInteger i;

    self = [super initWithWindowNibName: @"ChipTanWindow"];
    code = @"0FFF";
    code = [code stringByAppendingString: flickerCode];

    const char *cCode = [code UTF8String];
    codeLen = strlen(cCode);
    bitString = (char *)malloc(codeLen);
    const char *c = cCode;
    int        x;
    for (i = 0; i < codeLen; i += 2) {
        sscanf(c, "%1x", &x);
        bitString[i + 1] = (char)(x << 1);
        sscanf(c + 1, "%1x", &x);
        bitString[i] = (char)(x << 1);
        c += 2;
    }
    frequency = FREQ_DEFAULT;
    clock = 1;
    currentCode = 0;
    message = [msg stringByReplacingOccurrencesOfString: @"\n" withString: @"<br>"];
    self.userMessage = [NSString stringWithFormat:NSLocalizedString(@"AP184", ""), name];
    return self;
}

- (void)awakeFromNib
{
    NSMutableAttributedString *msgString = [[NSMutableAttributedString alloc] initWithHTML: [message dataUsingEncoding: NSISOLatin1StringEncoding] documentAttributes: nil];
    if (msgString != nil) {
        [[messageView textStorage] setAttributedString: msgString];
    } else {
        LogInfo(@"ChipTanWindowController: message could not be converted from HTML");
        NSData *data = [message dataUsingEncoding:NSISOLatin1StringEncoding];
        LogInfo(@"Data in base64: %@", data.base64Encoding);
    }
    [[messageView textStorage] setAttributedString: msgString];
    [frequencySlider setMaxValue: FREQ_MAX];
    [frequencySlider setMinValue: FREQ_MIN];
    frequency = (int)[frequencySlider floatValue];
    if (frequency < FREQ_MIN || frequency > FREQ_MAX) {
        [frequencySlider setFloatValue: FREQ_DEFAULT];
        frequency = FREQ_DEFAULT;
    }
    [sizeSlider setMaxValue: FLICKER_SIZE_MAX];
    [sizeSlider setMinValue: FLICKER_SIZE_MIN];
    int size = (int)[sizeSlider floatValue];
    if (size < FLICKER_SIZE_MIN || size > FLICKER_SIZE_MAX) {
        [sizeSlider setFloatValue: FLICKER_SIZE_DEFAULT];
    }
    flickerView.size = size;
    timer = [NSTimer timerWithTimeInterval: 1.0 / frequency target: self selector: @selector(clock:) userInfo: nil repeats: YES];
    [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSModalPanelRunLoopMode];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL           showTAN = [defaults boolForKey: @"showTAN"];
    if (showTAN) {
        [[self window] makeFirstResponder: tanField];
    } else {
        [[self window] makeFirstResponder: secureTanField];
    }
}

- (void)clock: (NSTimer *)timer
{
    char code = bitString[currentCode];
    code |= clock;

    flickerView.code = code;
    [flickerView setNeedsDisplay: YES];

    clock -= 1;
    if (clock < 0) {
        clock = 1;
        currentCode++;
        if (currentCode >= codeLen) {
            currentCode = 0;
        }
    }
}

- (IBAction)frequencySliderChanged: (id)sender
{
    [timer invalidate];
    frequency = (int)[frequencySlider floatValue];
    timer = [NSTimer timerWithTimeInterval: 1.0 / frequency target: self selector: @selector(clock:) userInfo: nil repeats: YES];
    [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSModalPanelRunLoopMode];
}

- (IBAction)sizeSliderChanged: (id)sender
{
    int size = (int)[sizeSlider floatValue];
    flickerView.size = size;
    [flickerView setNeedsDisplay: YES];
}

- (void)windowWillClose: (NSNotification *)aNotification
{
    [timer invalidate];
    if (tan == nil) {
        [NSApp stopModalWithCode: 1];
    }
}

- (IBAction)ok: (id)sender
{
    if (self.tan && [self.tan length] > 0) {
        [NSApp stopModalWithCode: 0];
        [[self window] close];
    }
}

- (IBAction)cancel: (id)sender
{
    [[self window] close];
}

- (void)dealloc
{
    tan = nil;
    if (bitString) {
        free(bitString);
    }
}

@end
