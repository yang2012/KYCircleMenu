//
//  KYCircleMenu.m
//  KYCircleMenu
//
//  Created by Kaijie Yu on 2/1/12.
//  Copyright (c) 2012 Kjuly. All rights reserved.
//

#import "KYCircleMenu.h"
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <RACEXTScope.h>

@interface KYCircleMenu ()

@property (nonatomic, assign) CGFloat centerButtonSize;
@property (nonatomic, assign) CGFloat buttonSize;

@property (nonatomic, assign) CGPoint centerButtonCenterPosition;
@property (nonatomic, assign) CGRect buttonOriginFrame;
@property (nonatomic, assign) BOOL shouldRecoverToNormalStatusWhenViewWillAppear;

@property (nonatomic, strong) NSString *centerButtonImageName;
@property (nonatomic, strong) NSString *centerButtonHighlightedImageName;

@property (nonatomic, strong) NSMutableArray *buttons;
@property (nonatomic, strong) UIImageView *centerButton;
@property (nonatomic, weak) UIButton *activeButton;

@property (nonatomic, strong) RACSubject *menuOpenSignal;
@property (nonatomic, strong) RACSubject *menuNeedToClosedSignal;

// Basic configuration for the Circle Menu
@property (nonatomic, assign) CGFloat defaultTriangleHypotenuse;
@property (nonatomic, assign) CGFloat minBounceOfTriangleHypotenuse;
@property (nonatomic, assign) CGFloat maxBounceOfTriangleHypotenuse;
@property (nonatomic, assign) CGFloat maxTriangleHypotenuse;

- (void)_releaseSubviews;
- (void)_setupNotificationObserver;

// Toggle menu beween open & closed
- (void)_toggle:(id)sender;
// Close menu to hide all buttons around
- (void)_close:(NSNotification *)notification;
// Update buttons' layout with the value of triangle hypotenuse that given
- (void)_updateButtonsLayoutWithTriangleHypotenuse:(CGFloat)triangleHypotenuse;
// Update button's origin value
- (void)_setButtonAtPosition:(KYCircleMenuPosition)position origin:(CGPoint)origin;

@end


@implementation KYCircleMenu

-(void)dealloc {
    self.centerButtonImageName = nil;
    self.centerButtonHighlightedImageName = nil;
    // Release subvies & remove notification observer
    [self _releaseSubviews];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kKYNCircleMenuClose object:nil];
}

- (void)_releaseSubviews {
    [self.centerButton removeFromSuperview];
    self.centerButton = nil;
}

// Designated initializer

- (id)          initWithMenuSize:(CGFloat)menuSize
                      buttonSize:(CGFloat)buttonSize
                centerButtonSize:(CGFloat)centerButtonSize
      centerButtonCenterPosition:(CGPoint)centerPosition
           centerButtonImageName:(NSString *)centerButtonImageName
centerButtonHighlightedImageName:(NSString *)centerButtonHighlightedImageName {
    if (self = [self init]) {
        self.buttonSize                         = buttonSize;
        self.centerButtonSize                   = centerButtonSize;
        self.centerButtonCenterPosition         = centerPosition;
        self.centerButtonImageName              = centerButtonImageName;
        self.centerButtonHighlightedImageName   = centerButtonHighlightedImageName;
        
        CGFloat maxWidth = CGRectGetWidth([UIScreen mainScreen].applicationFrame);
          
        // Defualt value for triangle hypotenuse
        self.defaultTriangleHypotenuse     = (menuSize - buttonSize) / 2.f;
        self.minBounceOfTriangleHypotenuse = self.defaultTriangleHypotenuse - 12.f;
        self.maxBounceOfTriangleHypotenuse = self.defaultTriangleHypotenuse + 12.f;
        self.maxTriangleHypotenuse         = maxWidth / 2.f;

        // Buttons' origin frame
        CGFloat originX = self.centerButtonCenterPosition.x - (self.centerButtonSize / 2);
        CGFloat originY = self.centerButtonCenterPosition.y - (self.centerButtonSize / 2);
        self.buttonOriginFrame =
          (CGRect){{originX, originY}, {self.centerButtonSize, self.centerButtonSize}};
        
        self.buttons = [NSMutableArray array];
        
        self.menuOpenSignal = [RACSubject subject];
        self.menuNeedToClosedSignal = [RACSubject subject];
    }
    return self;
}

// Secondary initializer
- (id)init {
  self = [super init];
  if (self) {
    self.isInProcessing = NO;
    self.isOpening      = NO;
    self.isClosed       = YES;
    self.shouldRecoverToNormalStatusWhenViewWillAppear = NO;
  }
  return self;
}

#pragma mark - View lifecycle

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // Main Button
    CGRect mainButtonFrame =
    CGRectMake(self.centerButtonCenterPosition.x - (self.centerButtonSize / 2), self.centerButtonCenterPosition.y - (self.centerButtonSize / 2),
               self.centerButtonSize, self.centerButtonSize);
    self.centerButton = [[UIImageView alloc] initWithFrame:mainButtonFrame];
    self.centerButton.userInteractionEnabled = YES;
    [self.centerButton setImage:[UIImage imageNamed:self.centerButtonImageName]];
    [self.centerButton setHighlightedImage:[UIImage imageNamed:self.centerButtonHighlightedImageName]];
    [self addSubview:self.centerButton];
    
    // Listen to gesture
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] init];
    tapGestureRecognizer.numberOfTapsRequired = 1;
    tapGestureRecognizer.enabled = YES;
    [self.centerButton addGestureRecognizer:tapGestureRecognizer];
    
    [tapGestureRecognizer.rac_gestureSignal subscribeNext:^(id x) {
        if ([self.circleDelegate respondsToSelector:@selector(circleMenuDidTapCenterButton:)]) {
            [self.circleDelegate circleMenuDidTapCenterButton:self];
        }
    }];
    
    RAC(self.centerButton, highlighted) = [[tapGestureRecognizer.rac_gestureSignal filter:^BOOL(UITapGestureRecognizer *tapGesture) {
        return tapGesture.state == UIGestureRecognizerStateEnded;
    }] map:^id(id value) {
        return @YES;
    }];
    
    UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] init];
    panGestureRecognizer.enabled = YES;
    panGestureRecognizer.cancelsTouchesInView = NO;
    [self.centerButton addGestureRecognizer:panGestureRecognizer];
    
    [self rac_liftSelector:@selector(_handlePanGesture:) withSignals:panGestureRecognizer.rac_gestureSignal, nil];
    
    RACSignal *closeSignal = [RACSignal zip:@[self.menuNeedToClosedSignal, self.menuOpenSignal]];
    [self rac_liftSelector:@selector(_close:) withSignals:closeSignal, nil];

    // Setup notification observer
    [self _setupNotificationObserver];
}

#pragma mark - Publich Button Action

- (void)addButtonWithImageName:(NSString *)imageName
          highlightedImageName:(NSString *)highlightedImageName
                      position:(KYCircleMenuPosition)position
{
    UIButton * button = [self _buttonAtPosition:position];
    if (button) {
        [self.buttons removeObject:button];
        [button removeFromSuperview];
    }
    
    // Add buttons to |ballMenu_|, set it's origin frame to center
    button = [[UIButton alloc] initWithFrame:self.buttonOriginFrame];
    [button setOpaque:NO];
    [button setTag:position];
    [button setImage:[UIImage imageNamed:imageName]
            forState:UIControlStateNormal];
    [button setImage:[UIImage imageNamed:highlightedImageName]
            forState:UIControlStateHighlighted];
    [button addTarget:self action:@selector(runButtonActions:) forControlEvents:UIControlEventTouchUpInside];
    button.alpha = 0.0f;
    [self addSubview:button];
    [self.buttons addObject:button];
}

// Open center menu view
- (void)open {
  if (self.isOpening)
    return;
  self.isInProcessing = YES;
  // Show buttons with animation
  [UIView animateWithDuration:.3f
                        delay:0.f
                      options:UIViewAnimationOptionCurveEaseInOut
                   animations:^{
                       for (UIButton *button in self.buttons) {
                           button.alpha = 1.0f;
                       }
                     // Compute buttons' frame and set for them, based on |buttonCount|
                     [self _updateButtonsLayoutWithTriangleHypotenuse:self.maxBounceOfTriangleHypotenuse];
                   }
                   completion:^(BOOL finished) {
                     [UIView animateWithDuration:.1f
                                           delay:0.f
                                         options:UIViewAnimationOptionCurveEaseInOut
                                      animations:^{
                                        [self _updateButtonsLayoutWithTriangleHypotenuse:self.defaultTriangleHypotenuse];
                                      }
                                      completion:^(BOOL finished) {
                                          self.isOpening = YES;
                                          self.isClosed = NO;
                                          self.isInProcessing = NO;
                                          
                                          [self.menuOpenSignal sendNext:nil];
                                      }];
                   }];
}

// Recover to normal status
- (void)recoverToNormalStatus {
  [self _updateButtonsLayoutWithTriangleHypotenuse:self.maxTriangleHypotenuse];
  [UIView animateWithDuration:.3f
                        delay:0.f
                      options:UIViewAnimationOptionCurveEaseInOut
                   animations:^{
                     // Show buttons & slide in to center
                       for (UIButton *button in self.buttons) {
                           button.alpha = 1.0f;
                       }
                     [self _updateButtonsLayoutWithTriangleHypotenuse:self.minBounceOfTriangleHypotenuse];
                   }
                   completion:^(BOOL finished) {
                     [UIView animateWithDuration:.1f
                                           delay:0.f
                                         options:UIViewAnimationOptionCurveEaseInOut
                                      animations:^{
                                        [self _updateButtonsLayoutWithTriangleHypotenuse:self.defaultTriangleHypotenuse];
                                      }
                                      completion:nil];
                   }];
}

- (void)hideWithCompletionBlock:(void (^)())block
{
    [UIView animateWithDuration:.3f
                          delay:0.f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         // Slide away buttons in center view & hide them
                         [self _updateButtonsLayoutWithTriangleHypotenuse:self.maxTriangleHypotenuse];
                         for (UIButton *button in self.buttons) {
                             button.alpha = 0.0f;
                         }
                         
                         /*/ Show Navigation Bar
                          [self.navigationController setNavigationBarHidden:NO];
                          CGRect navigationBarFrame = self.navigationController.navigationBar.frame;
                          if (navigationBarFrame.origin.y < 0) {
                          navigationBarFrame.origin.y = 0;
                          [self.navigationController.navigationBar setFrame:navigationBarFrame];
                          }*/
                     }
                     completion:^(BOOL finished) {
                         block();
                     }];
}

#pragma mark - Private Methods

// Setup notification observer
- (void)_setupNotificationObserver {
  // Add Observer for close self
  // If |centerMainButton_| post cancel notification, do it
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(_close:)
                                               name:kKYNCircleMenuClose
                                             object:nil];
}

- (void)_handlePanGesture:(UIPanGestureRecognizer *)panGestureRecognizer
{
    CGPoint location = [panGestureRecognizer locationInView:self];
    switch (panGestureRecognizer.state) {
        case UIGestureRecognizerStateBegan:
            self.centerButton.highlighted = YES;
            [self open];
            break;
        case UIGestureRecognizerStateChanged:
            for (UIButton *button in self.buttons) {
                CGRect frame = button.frame;
                if (CGRectContainsPoint(frame, location)) {
                    if (![self.activeButton isEqual:button]) {
                        if (self.activeButton != nil) {
                            // left previous button and enter a new button
                            self.activeButton.highlighted = NO;
                        }
                        
                        button.highlighted = YES;
                        self.activeButton = button;
                    }
                } else {
                    if (self.activeButton == button) {
                        button.highlighted = NO;
                        self.activeButton = nil;
                    }
                }
            }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            if (self.activeButton) {
                [self _runButtonActions:self.activeButton];
                
                self.activeButton.highlighted = NO;
                self.activeButton = nil;
            }
            self.centerButton.highlighted = NO;
            [self.menuNeedToClosedSignal sendNext:nil];
            break;
        default:
            break;
    }
}

// Toggle Circle Menu
- (void)_toggle:(id)sender {
  (self.isClosed ? [self open] : [self _close:nil]);
}

// Close menu to hide all buttons around
- (void)_close:(NSNotification *)notification {
  if (self.isClosed)
    return;
  
  self.isInProcessing = YES;
  // Hide buttons with animation
  [UIView animateWithDuration:.3f
                        delay:0.f
                      options:UIViewAnimationOptionCurveEaseIn
                   animations:^{
                       for (UIButton * button in self.buttons) {
                           [button setFrame:self.buttonOriginFrame];
                           button.alpha = 0.0f;
                       }
                   }
                   completion:^(BOOL finished) {
                     self.isClosed       = YES;
                     self.isOpening      = NO;
                     self.isInProcessing = NO;
                       
                       
                   }];
}

// Update buttons' layout with the value of triangle hypotenuse that given
- (void)_updateButtonsLayoutWithTriangleHypotenuse:(CGFloat)triangleHypotenuse {
    //
    //  Triangle Values for Buttons' Position
    // 
    //      /|      a: triangleA = c * cos(x)
    //   c / | b    b: triangleB = c * sin(x)
    //    /)x|      c: triangleHypotenuse
    //   -----      x: degree
    //     a
    //
    CGFloat buttonRadius           = self.centerButtonSize / 2.f;
    if (! triangleHypotenuse) triangleHypotenuse = self.defaultTriangleHypotenuse; // Distance to Ball Center

    //
    //      o       o   o      o   o     o   o     o o o     o o o
    //     \|/       \|/        \|/       \|/       \|/       \|/
    //  1 --|--   2 --|--    3 --|--   4 --|--   5 --|--   6 --|--
    //     /|\       /|\        /|\       /|\       /|\       /|\
    //                           o       o   o     o   o     o o o
    //
    CGFloat degree    = M_PI / 3.0f; // = 60 * M_PI / 180
    CGFloat triangleA = triangleHypotenuse * cosf(degree);
    CGFloat triangleB = triangleHypotenuse * sinf(degree);
    [self _setButtonAtPosition:KYCircleMenuPositionTopLeft origin:CGPointMake(self.centerButtonCenterPosition.x - triangleB - buttonRadius,
                                                 self.centerButtonCenterPosition.y - triangleA - buttonRadius)];
    [self _setButtonAtPosition:KYCircleMenuPositionTopCenter origin:CGPointMake(self.centerButtonCenterPosition.x - buttonRadius,
                                                 self.centerButtonCenterPosition.y - triangleHypotenuse - buttonRadius)];
    [self _setButtonAtPosition:KYCircleMenuPositionTopRight origin:CGPointMake(self.centerButtonCenterPosition.x + triangleB - buttonRadius,
                                                 self.centerButtonCenterPosition.y - triangleA - buttonRadius)];
    [self _setButtonAtPosition:KYCircleMenuPositionBottomLeft origin:CGPointMake(self.centerButtonCenterPosition.x - triangleB - buttonRadius,
                                                 self.centerButtonCenterPosition.y + triangleA - buttonRadius)];
    [self _setButtonAtPosition:KYCircleMenuPositionBottomCenter origin:CGPointMake(self.centerButtonCenterPosition.x - buttonRadius,
                                                 self.centerButtonCenterPosition.y + triangleHypotenuse - buttonRadius)];
    [self _setButtonAtPosition:KYCircleMenuPositionBottomRight origin:CGPointMake(self.centerButtonCenterPosition.x + triangleB - buttonRadius,
                                                 self.centerButtonCenterPosition.y + triangleA - buttonRadius)];
}

// Run action depend on button, it'll be implemented by subclass
- (void)_runButtonActions:(id)sender {
    UIButton *button = (UIButton *)sender;
    if (button == nil) {
        return;
    }
    KYCircleMenuPosition position = [self _positionOfButton:button];
    if ([self.circleDelegate respondsToSelector:@selector(circleMenu:clickedButtonAtPosition:)]) {
        [self.circleDelegate circleMenu:self clickedButtonAtPosition:position];
    }
    self.shouldRecoverToNormalStatusWhenViewWillAppear = YES;
}

// Set Frame for button with special tag
- (void)_setButtonAtPosition:(KYCircleMenuPosition)position origin:(CGPoint)origin {
    UIButton * button = [self _buttonAtPosition:position];
    if (button) {
        [button setFrame:CGRectMake(origin.x, origin.y, self.centerButtonSize, self.centerButtonSize)];
    }
}

- (UIButton *)_buttonAtPosition:(KYCircleMenuPosition)position
{
    return (UIButton *)[self viewWithTag:position];
}

- (KYCircleMenuPosition)_positionOfButton:(UIButton *)button
{
    return (KYCircleMenuPosition)button.tag;
}

@end
