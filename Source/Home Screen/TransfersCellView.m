/**
 * Copyright (c) 2013, Pecunia Project. All rights reserved.
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

#import "TransfersCellView.h"
#import "StatCatAssignment.h"
#import "BankingCategory.h"
#import "NSColor+PecuniaAdditions.h"

extern void *UserDefaultsBindingContext;

@interface TransfersCellView ()
{
}
@end

@implementation TransfersCellView

- (void)awakeFromNib
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults addObserver: self forKeyPath: @"colors" options: 0 context: UserDefaultsBindingContext];
    [self updateValueColors];
}

- (void)dealloc
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults removeObserver: self forKeyPath: @"colors"];
}

- (void)drawRect: (NSRect)dirtyRect
{
    [[NSColor colorWithCalibratedWhite: 1 alpha: 0.5] setFill];
    //NSRectFill(dirtyRect);

    [[NSColor colorWithCalibratedWhite: 1 alpha: 1] setFill];
    //NSFrameRect(dirtyRect);
}

- (void)updateValueColors
{
    NSDictionary *positiveAttributes = @{NSForegroundColorAttributeName: [NSColor applicationColorForKey: @"Positive Cash"]};
    NSDictionary *negativeAttributes = @{NSForegroundColorAttributeName: [NSColor applicationColorForKey: @"Negative Cash"]};

    [[valueField.cell formatter] setTextAttributesForPositiveValues: positiveAttributes];
    [[valueField.cell formatter] setTextAttributesForNegativeValues: negativeAttributes];
    [valueField setNeedsDisplay: YES];
}

#pragma mark - KVO

- (void)observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context
{
    if (context == UserDefaultsBindingContext) {
        if ([keyPath isEqualToString: @"colors"]) {
            [self updateValueColors];
        }
        return;
    }
    [super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
}

@end

@implementation TransfersRowView

static NSGradient *headerGradient;

+ (void)initialize
{
    headerGradient = [[NSGradient alloc] initWithColorsAndLocations:
                      [NSColor colorWithCalibratedRed: 0.566 green: 0.557 blue: 0.530 alpha: 0.750], 0.0,
                      [NSColor colorWithCalibratedRed: 0.497 green: 0.488 blue: 0.461 alpha: 0.750], 1.0,
                      nil];
}

- (id)initWithFrame: (NSRect)frame
{
    self = [super initWithFrame: frame];
    if (self != nil) {
    }

    return self;
}

- (void)drawSelectionInRect: (NSRect)dirtyRect
{
    // No selection needed.
}

- (void)drawBackgroundInRect: (NSRect)dirtyRect
{
    NSRect rect = NSIntersectionRect(dirtyRect, self.bounds);
    if (self.isGroupRowStyle) {
        rect.origin.x++;
        rect.size.width -= 3;
        rect.size.height -= 1;
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect: rect xRadius: 2 yRadius: 2];
        [headerGradient drawInBezierPath: path angle: 90.0];
    }
}

@end
