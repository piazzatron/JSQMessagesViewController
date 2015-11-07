//
//  Created by Jesse Squires
//  http://www.jessesquires.com
//
//
//  Documentation
//  http://cocoadocs.org/docsets/JSQMessagesViewController
//
//
//  GitHub
//  https://github.com/jessesquires/JSQMessagesViewController
//
//
//  License
//  Copyright (c) 2014 Jesse Squires
//  Released under an MIT license: http://opensource.org/licenses/MIT
//

#import "JSQMessagesBubblesSizeCalculator.h"

#import "JSQMessagesCollectionView.h"
#import "JSQMessagesCollectionViewDataSource.h"
#import "JSQMessagesCollectionViewFlowLayout.h"
#import "JSQMessageData.h"

#import "UIImage+JSQMessages.h"


@interface JSQMessagesBubblesSizeCalculator ()

@property (strong, nonatomic, readonly) NSCache *cache;

@property (assign, nonatomic, readonly) NSUInteger minimumBubbleWidth;

@end


@implementation JSQMessagesBubblesSizeCalculator

#pragma mark - Init

- (instancetype)initWithCache:(NSCache *)cache minimumBubbleWidth:(NSUInteger)minimumBubbleWidth
{
    NSParameterAssert(cache != nil);
    NSParameterAssert(minimumBubbleWidth > 0);

    self = [super init];
    if (self) {
        _cache = cache;
        _minimumBubbleWidth = minimumBubbleWidth;
    }
    return self;
}

- (instancetype)init
{
    NSCache *cache = [NSCache new];
    cache.name = @"JSQMessagesBubblesSizeCalculator.cache";
    cache.countLimit = 200;
    return [self initWithCache:cache
            minimumBubbleWidth:[UIImage jsq_bubbleCompactImage].size.width];
}

#pragma mark - NSObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: cache=%@, minimumBubbleWidth=%@>",
            [self class], self.cache, @(self.minimumBubbleWidth)];
}

#pragma mark - JSQMessagesBubbleSizeCalculating

- (void)prepareForResettingLayout:(JSQMessagesCollectionViewFlowLayout *)layout
{
    [self.cache removeAllObjects];
}

- (CGSize)messageBubbleSizeForMessageData:(id<JSQMessageData>)messageData
                              atIndexPath:(NSIndexPath *)indexPath
                               withLayout:(JSQMessagesCollectionViewFlowLayout *)layout
{
    NSValue *cachedSize = [self.cache objectForKey:@([messageData messageHash])];
    if (cachedSize != nil) {
        return [cachedSize CGSizeValue];
    }

    CGSize finalSize = CGSizeZero;

    if ([messageData isMediaMessage]) {
        finalSize = [[messageData media] mediaViewDisplaySize];
    }
    else {
        CGSize avatarSize = [self jsq_avatarSizeForMessageData:messageData withLayout:layout];

        //  from the cell xibs, there is a 2 point space between avatar and bubble
        CGFloat spacingBetweenAvatarAndBubble = 2.0f;
        CGFloat horizontalContainerInsets = layout.messageBubbleTextViewTextContainerInsets.left + layout.messageBubbleTextViewTextContainerInsets.right;
        CGFloat horizontalFrameInsets = layout.messageBubbleTextViewFrameInsets.left + layout.messageBubbleTextViewFrameInsets.right;

        CGFloat horizontalInsetsTotal = horizontalContainerInsets + horizontalFrameInsets + spacingBetweenAvatarAndBubble;
        CGFloat maximumTextWidth = layout.itemWidth - avatarSize.width - layout.messageBubbleLeftRightMargin - horizontalInsetsTotal;

        CGRect stringRect = [[messageData text] boundingRectWithSize:CGSizeMake(maximumTextWidth, CGFLOAT_MAX)
                                                             options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                                          attributes:@{ NSFontAttributeName : layout.messageBubbleFont }
                                                             context:nil];

        CGSize stringSize = CGRectIntegral(stringRect).size;
        
        /*
         From the docs about 'boundingRectWithSize...':
         
         "This method returns the actual bounds of the glyphs in the string. Some of the glyphs (spaces, for example) are allowed to overlap the layout constraints specified by the size passed in, so in some cases the width value of the size component of the returned CGRect can exceed the width value of the size parameter."
         
         The text will fit in the bounding width, even if the returned rect is larger than that width. Thus, we should make sure that the size
         we are using for the text view is NOT larger than the size we claimed we would bound the text with.
         */
        
        if (stringSize.width > maximumTextWidth) {
            stringSize.width = maximumTextWidth;
        }

        CGFloat verticalContainerInsets = layout.messageBubbleTextViewTextContainerInsets.top + layout.messageBubbleTextViewTextContainerInsets.bottom;
        CGFloat verticalFrameInsets = layout.messageBubbleTextViewFrameInsets.top + layout.messageBubbleTextViewFrameInsets.bottom;

        CGFloat verticalInsets = verticalContainerInsets + verticalFrameInsets;

        CGFloat finalWidth = MAX(stringSize.width + horizontalInsetsTotal - spacingBetweenAvatarAndBubble, self.minimumBubbleWidth);

        finalSize = CGSizeMake(finalWidth, stringSize.height + verticalInsets);
    }

    [self.cache setObject:[NSValue valueWithCGSize:finalSize] forKey:@([messageData messageHash])];

    return finalSize;
}

- (CGSize)jsq_avatarSizeForMessageData:(id<JSQMessageData>)messageData
                            withLayout:(JSQMessagesCollectionViewFlowLayout *)layout
{
    NSString *messageSender = [messageData senderId];

    if ([messageSender isEqualToString:[layout.collectionView.dataSource senderId]]) {
        return layout.outgoingAvatarViewSize;
    }
    
    return layout.incomingAvatarViewSize;
}

@end