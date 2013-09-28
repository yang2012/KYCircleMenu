//
//  KYCircleMenu.h
//  KYCircleMenu
//
//  Created by Kaijie Yu on 2/1/12.
//  Copyright (c) 2012 Kjuly. All rights reserved.
//

#import <UIKit/UIKit.h>

// The default case is that the navigation bar is only shown in child views.
// If it is needed to be shown with the circle menu together,
//   just copy this macro into your own config file & comment it out.
//

// Notification to close the menu
#define kKYNCircleMenuClose @"KYNCircleMenuClose"

typedef enum
{
    KYCircleMenuPositionTopLeft = 111,
    KYCircleMenuPositionTopCenter,
    KYCircleMenuPositionTopRight,
    KYCircleMenuPositionBottomLeft,
    KYCircleMenuPositionBottomCenter,
    KYCircleMenuPositionBottomRight,
} KYCircleMenuPosition;

@class KYCircleMenu;

@protocol KYCircleMenuDelegate <NSObject>

- (void)circleMenu:(KYCircleMenu *)circleMenu clickedButtonAtPosition:(KYCircleMenuPosition)position;
- (void)circleMenuDidTapCenterButton:(KYCircleMenu *)circleMenu;

@end

@interface KYCircleMenu : UIView

@property (nonatomic, assign) BOOL          isOpening;
@property (nonatomic, assign) BOOL          isInProcessing;
@property (nonatomic, assign) BOOL          isClosed;

@property (nonatomic, weak) id<KYCircleMenuDelegate> circleDelegate;

/*! Designated initializer for KYCircleMenu.
 *
 * \param buttonCount Count of buttons around (1<= x <=6)
 * \param menuSize Size of menu
 * \param buttonSize Size of buttons around
 * \param buttonImageNameFormat Name format for button image
 * \param centerButtonSize Size of center button
 * \param centerButtonImageName Name for center button image
 * \param centerButtonBackgroundImageName Name for center button background image
 *
 * \returns An KYCircleMenu instance
 */
- (id)          initWithMenuSize:(CGFloat)menuSize
                      buttonSize:(CGFloat)buttonSize
                centerButtonSize:(CGFloat)centerButtonSize
      centerButtonCenterPosition:(CGPoint)centerPosition
           centerButtonImageName:(NSString *)centerButtonImageName
centerButtonHighlightedImageName:(NSString *)centerButtonHighlightedImageName;

- (void)addButtonWithImageName:(NSString *)imageName
          highlightedImageName:(NSString *)highlightedImageName
                      position:(KYCircleMenuPosition)position;

/*! Open menu to show all buttons around
 */
- (void)open;

/*! Recover all buttons to normal position
 */
- (void)recoverToNormalStatus;

- (void)hideWithCompletionBlock:(void (^)())block;

@end
