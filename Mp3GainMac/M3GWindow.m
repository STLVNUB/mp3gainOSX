//
//  M3GWindow.m
//  MP3GainExpress
//
//  Created by Paul Kratt on 4/29/17.
//
//

#import "M3GWindow.h"

@implementation M3GWindow

-(void)awakeFromNib{
    NSString *osxMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    //Note that since Dark Mode is officially supported in macOS 10.14, this hack is only used from 10.11 to 10.13.
    //I could have removed it completely, but some people might like having the feature.
    if([osxMode isEqualToString:@"Dark"] && NSAppKitVersionNumber >= NSAppKitVersionNumber10_11 && NSAppKitVersionNumber <= NSAppKitVersionNumber10_13 && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldIncreaseContrast){
        //This dark mode hack breaks if "Increase Contrast" is enabled in Accessiblity settings, so we don't support that.
        //Since I'm already doing something that I'm not supposed to, fixing it would be a lot more work than just disabling it.
        _originalView = self.contentView;
        NSRect contentFrame = self.contentView.frame;
        NSRect windowFrame = self.frame;
        
        self.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
        self.titlebarAppearsTransparent = YES;
        
        //NSVisualEffectView is only available in 10.10 and later. But so is Dark mode, so I shouldn't need to check if it exists.
        NSVisualEffectView* vev = [NSVisualEffectView new];
        vev.frame = contentFrame;
        vev.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        vev.state = NSVisualEffectStateActive;
        vev.material = NSVisualEffectMaterialUltraDark; //Ultra dark is only available in 10.11 or later.
        self.styleMask = self.styleMask | NSFullSizeContentViewWindowMask;
        self.contentView = vev;
        
        [vev addSubview:_originalView];
        [_originalView setFrame:self.contentLayoutRect];
        [self setFrame:windowFrame display:YES];
        self.delegate = self;
        
        [self addObserver:self forKeyPath:@"contentLayoutRect" options:NSKeyValueObservingOptionNew context:nil];
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if([keyPath isEqualToString:@"contentLayoutRect"]){
        [_originalView setFrame:self.contentLayoutRect];
    }
}

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet
       usingRect:(NSRect)rect {
    NSRect region = self.contentLayoutRect;
    region.origin.y = region.origin.y + region.size.height;
    region.size.height = 0;
    return region;
}

@end
