// VENTokenField.m
//
// Copyright (c) 2014 Venmo
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "VENTokenField.h"

#import <FrameAccessor/FrameAccessor.h>
#import "VENToken.h"
#import "VENBackspaceTextField.h"

static const CGFloat VENTokenFieldDefaultVerticalInset      = 7.0;
static const CGFloat VENTokenFieldDefaultHorizontalInset    = 15.0;
static const CGFloat VENTokenFieldDefaultToLabelPadding     = 5.0;
static const CGFloat VENTokenFieldDefaultTokenPadding       = 2.0;
static const CGFloat VENTokenFieldDefaultMinInputWidth      = 80.0;
static const CGFloat VENTokenFieldDefaultMaxHeight          = 75.0;


@interface VENTokenField () <VENBackspaceTextFieldDelegate>

@property (strong, nonatomic) UIScrollView *scrollView;
@property (strong, nonatomic) NSMutableArray *tokens;
@property (assign, nonatomic) CGFloat originalHeight;
@property (strong, nonatomic) UITapGestureRecognizer *tapGestureRecognizer;
@property (strong, nonatomic) VENBackspaceTextField *invisibleTextField;
@property (strong, nonatomic) VENBackspaceTextField *inputTextField;
@property (strong, nonatomic) UIColor *colorScheme;

@property (nonatomic, assign) CGFloat intrinsicContentHeight;

@property (nonatomic) BOOL collapsed;
@property (nonatomic) BOOL exceptCollapse;

@end


@implementation VENTokenField

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setUpInit];
    }
    return self;
}

- (void)awakeFromNib
{
    [self setUpInit];
}

- (BOOL)isFirstResponder
{
    return [self.inputTextField isFirstResponder];
}

- (BOOL)becomeFirstResponder
{
    [self layoutTokensAndInputWithFrameAdjustment:YES shouldSetCollapsed:YES];
    [self inputTextFieldBecomeFirstResponder];
    return YES;
}

- (BOOL)resignFirstResponder
{
    [super resignFirstResponder];
    return [self.inputTextField resignFirstResponder];
}

- (void)setUpInit
{
    // Set up default values.
    _autocorrectionType = UITextAutocorrectionTypeNo;
    _autocapitalizationType = UITextAutocapitalizationTypeSentences;
    self.maxHeight = VENTokenFieldDefaultMaxHeight;
    self.verticalInset = VENTokenFieldDefaultVerticalInset;
    self.horizontalInset = VENTokenFieldDefaultHorizontalInset;
    self.tokenPadding = VENTokenFieldDefaultTokenPadding;
    self.minInputWidth = VENTokenFieldDefaultMinInputWidth;
    self.colorScheme = [UIColor blueColor];
    self.toLabelTextColor = [UIColor colorWithRed:112/255.0f green:124/255.0f blue:124/255.0f alpha:1.0f];
    self.inputTextFieldTextColor = [UIColor colorWithRed:38/255.0f green:39/255.0f blue:41/255.0f alpha:1.0f];
    
    // Accessing bare value to avoid kicking off a premature layout run.
    _toLabelText = NSLocalizedString(@"To:", nil);

    self.originalHeight = CGRectGetHeight(self.frame);

    // Add invisible text field to handle backspace when we don't have a real first responder.
    [self layoutInvisibleTextField];

    [self layoutScrollView];
    [self reloadData];
}

- (void)collapse
{
    [self.inputTextField resignFirstResponder];
    self.collapsed = YES;
    [self layoutTokensAndInputWithFrameAdjustment:YES shouldSetCollapsed:NO];
}

- (void)expand
{
    self.exceptCollapse = NO;
    if(self.collapsed) {
        [self layoutTokensAndInputWithFrameAdjustment:YES shouldSetCollapsed:YES];
    }
}

- (void)scrollToTop
{
    [self.scrollView setContentOffset:CGPointMake(self.scrollView.contentOffset.x, -self.verticalInset) animated:YES];
}

- (void)reloadData
{
    [self layoutTokensAndInputWithFrameAdjustment:YES shouldSetCollapsed:YES];
}

- (void)setPlaceholderText:(NSString *)placeholderText
{
    _placeholderText = placeholderText;
    self.inputTextField.placeholder = _placeholderText;
}

-(void)setInputTextFieldAccessibilityLabel:(NSString *)inputTextFieldAccessibilityLabel {
    _inputTextFieldAccessibilityLabel = inputTextFieldAccessibilityLabel;
    self.inputTextField.accessibilityLabel = _inputTextFieldAccessibilityLabel;
}

- (void)setInputTextFieldTextColor:(UIColor *)inputTextFieldTextColor
{
    _inputTextFieldTextColor = inputTextFieldTextColor;
    self.inputTextField.textColor = _inputTextFieldTextColor;
}

- (void)setToLabelTextColor:(UIColor *)toLabelTextColor
{
    _toLabelTextColor = toLabelTextColor;
    self.toLabel.textColor = _toLabelTextColor;
}

- (void)setToLabelText:(NSString *)toLabelText
{
    _toLabelText = toLabelText;
    [self reloadData];
}

- (void)setColorScheme:(UIColor *)color
{
    _colorScheme = color;
    self.inputTextField.tintColor = color;
    for (VENToken *token in self.tokens) {
        [token setColorScheme:color];
    }
}

- (void)setInputTextFieldAccessoryView:(UIView *)inputTextFieldAccessoryView
{
    _inputTextFieldAccessoryView = inputTextFieldAccessoryView;
    self.inputTextField.inputAccessoryView = _inputTextFieldAccessoryView;
}

- (NSString *)inputText
{
    return self.inputTextField.text;
}

- (VENToken *)tokenAtIndex:(NSUInteger)index {
    return self.tokens[index];
}

#pragma mark - View Layout

- (void)setIntrinsicContentHeight:(CGFloat)intrinsicContentHeight {
    _intrinsicContentHeight = intrinsicContentHeight;
    [self invalidateIntrinsicContentSize];
}

- (CGSize)intrinsicContentSize {

    return CGSizeMake(UIViewNoIntrinsicMetric,
                      MIN(MAX(self.intrinsicContentHeight, self.originalHeight), self.maxHeight));
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.scrollView.contentSize = CGSizeMake(CGRectGetWidth(self.frame) - self.horizontalInset * 2, CGRectGetHeight(self.frame) - self.verticalInset * 2);
    [self layoutTokensAndInputWithFrameAdjustment:NO shouldSetCollapsed:NO];
}

- (void)layoutTokensAndInputWithFrameAdjustment:(BOOL)shouldAdjustFrame shouldSetCollapsed:(BOOL)setCollapsed
{
      if(setCollapsed) {
          self.collapsed = NO;
      }
 //   self.tokens = [NSMutableArray array];
    BOOL inputFieldShouldBecomeFirstResponder = self.inputTextField.isFirstResponder;
    [self.scrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.scrollView.hidden = NO;
    [self removeGestureRecognizer:self.tapGestureRecognizer];

    CGFloat currentX = 0;
    CGFloat currentY = 0;

    [self layoutToLabelInView:self.scrollView origin:CGPointZero currentX:&currentX];
    [self layoutTokensWithCurrentX:&currentX currentY:&currentY];
    [self layoutInputTextFieldWithCurrentX:&currentX currentY:&currentY];

    [self adjustHeightForCurrentY:currentY];

    CGFloat contentHeight = currentY;
    if ((currentY + [self heightForToken]) > self.maxHeight) {
        contentHeight += [self heightForToken];
    }
    [self.scrollView setContentSize:CGSizeMake(self.scrollView.contentSize.width, contentHeight)];

    [self updateInputTextField];

    if (inputFieldShouldBecomeFirstResponder) {
        [self inputTextFieldBecomeFirstResponder];
    } else {
        [self focusInputTextField];
    }
}

- (void)layoutScrollView
{
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.frame), CGRectGetHeight(self.frame))];
    self.scrollView.scrollsToTop = NO;
    self.scrollView.contentSize = CGSizeMake(CGRectGetWidth(self.frame) - self.horizontalInset * 2, CGRectGetHeight(self.frame) - self.verticalInset * 2);
    self.scrollView.contentInset = UIEdgeInsetsMake(self.verticalInset,
                                                    self.horizontalInset,
                                                    self.verticalInset,
                                                    self.horizontalInset);
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;

    [self addSubview:self.scrollView];
}

- (void)layoutInputTextFieldWithCurrentX:(CGFloat *)currentX currentY:(CGFloat *)currentY
{
    CGFloat inputTextFieldWidth = self.scrollView.contentSize.width - *currentX;
    if (inputTextFieldWidth < self.minInputWidth) {
        inputTextFieldWidth = self.scrollView.contentSize.width;
        *currentY += [self heightForToken];
        *currentX = 0;
    }

    VENBackspaceTextField *inputTextField = self.inputTextField;
    inputTextField.text = @"";
    inputTextField.frame = CGRectMake(*currentX, *currentY + 1, inputTextFieldWidth, [self heightForToken] - 1);
    inputTextField.tintColor = self.colorScheme;
    [self.scrollView addSubview:inputTextField];
}

- (void)layoutToLabelInView:(UIView *)view origin:(CGPoint)origin currentX:(CGFloat *)currentX
{
    [self.toLabel removeFromSuperview];
    self.toLabel = [self toLabel];
    
    CGRect newFrame = self.toLabel.frame;
    newFrame.origin = origin;
    
    [self.toLabel sizeToFit];
    newFrame.size.width = CGRectGetWidth(self.toLabel.frame);
    
    self.toLabel.frame = newFrame;
    
    [view addSubview:self.toLabel];
    *currentX += self.toLabel.hidden ? CGRectGetMinX(self.toLabel.frame) : CGRectGetMaxX(self.toLabel.frame) + VENTokenFieldDefaultToLabelPadding;
}

- (void)layoutTokensWithCurrentX:(CGFloat *)currentX currentY:(CGFloat *)currentY
{
    NSMutableArray *localTokens = [NSMutableArray array];
    for (NSUInteger i = 0; i < [self numberOfTokens]; i++) {
        VENToken *token = [self tokenField:self tokenAtIndex:i];
        __weak VENToken *weakToken = token;
        __weak VENTokenField *weakSelf = self;
        token.didTapTokenBlock = ^{
            __typeof__(self) strongSelf = weakSelf;
            [strongSelf didTapToken:weakToken];
            if ([strongSelf.delegate respondsToSelector:@selector(tokenField:didTapTokenAtIndex:)]) {
                [strongSelf.delegate tokenField:strongSelf didTapTokenAtIndex:i];
            }
        };

        token.colorScheme = [self colorSchemeForTokenAtIndex:i];
        
      
        [token sizeToFit];
        CGFloat intrinsicWidth = token.intrinsicContentSize.width;
        if (*currentX + intrinsicWidth <= self.scrollView.contentSize.width) { // token fits in current line
            token.frame = CGRectMake(*currentX, *currentY, intrinsicWidth, token.height);
        } else {
              if(self.collapsed) {
                  int j = i;
                  BOOL tokenFits = NO;
                  VENToken *lastToken = [self.dataSource tokenField:self
                         lastTokenForCollapsedWithTokensRemaining:[self numberOfTokens] - (j)];
                  while(!tokenFits) {
                      if (*currentX + lastToken.width <= self.scrollView.contentSize.width) { // token fits in current line
                          lastToken.frame = CGRectMake(*currentX, *currentY, lastToken.intrinsicContentSize.width, lastToken.height);
                          tokenFits = YES;
                      } else {
                        j--;
                          if (j < 0) {
                              break;
                          }
                        VENToken *previous = localTokens[j];
                        [previous removeFromSuperview];
                        *currentX -= (previous.width + self.tokenPadding);
                        lastToken = [self.dataSource tokenField:self
                       lastTokenForCollapsedWithTokensRemaining:[self numberOfTokens] - (j)];
                      }
                  }
                  lastToken.frame = CGRectMake(*currentX, *currentY, lastToken.intrinsicContentSize.width, lastToken.height);
                  [self.scrollView addSubview:lastToken];
                  return;
              }
            *currentY += token.height;
            *currentX = 0;
            CGFloat tokenWidth = token.intrinsicContentSize.width;
            if (tokenWidth > self.scrollView.contentSize.width) { // token is wider than max width
                tokenWidth = self.scrollView.contentSize.width;
            }
            token.frame = CGRectMake(*currentX, *currentY, tokenWidth, token.height);
        }
        *currentX += token.width + self.tokenPadding;
        [self.scrollView addSubview:token];
        [localTokens addObject:token];
    }
  self.tokens = localTokens;
}


#pragma mark - Private

- (CGFloat)heightForToken
{
    return 30;
}

- (void)layoutInvisibleTextField
{
    self.invisibleTextField = [[VENBackspaceTextField alloc] initWithFrame:CGRectZero];
    [self.invisibleTextField setAutocorrectionType:self.autocorrectionType];
    [self.invisibleTextField setAutocapitalizationType:self.autocapitalizationType];
    self.invisibleTextField.backspaceDelegate = self;
    [self addSubview:self.invisibleTextField];
}

- (void)inputTextFieldBecomeFirstResponder
{
    if (self.inputTextField.isFirstResponder) {
        return;
    }

    [self.inputTextField becomeFirstResponder];
    if ([self.delegate respondsToSelector:@selector(tokenFieldDidBeginEditing:)]) {
        [self.delegate tokenFieldDidBeginEditing:self];
    }
}

- (UILabel *)toLabel
{
    if (!_toLabel) {
        _toLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _toLabel.textColor = self.toLabelTextColor;
        _toLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:15.5];
        _toLabel.x = 0;
        [_toLabel sizeToFit];
        [_toLabel setHeight:[self heightForToken]];
    }
    if (![_toLabel.text isEqualToString:_toLabelText]) {
        _toLabel.text = _toLabelText;
    }
    return _toLabel;
}

- (void)adjustHeightForCurrentY:(CGFloat)currentY
{
    [self setIntrinsicContentHeight:currentY + [self heightForToken] + self.verticalInset * 2];
}

- (VENBackspaceTextField *)inputTextField
{
    if (!_inputTextField) {
        _inputTextField = [[VENBackspaceTextField alloc] init];
        [_inputTextField setKeyboardType:self.inputTextFieldKeyboardType];
        _inputTextField.textColor = self.inputTextFieldTextColor;
        _inputTextField.font = [UIFont fontWithName:@"HelveticaNeue" size:15.5];
        _inputTextField.autocorrectionType = self.autocorrectionType;
        _inputTextField.autocapitalizationType = self.autocapitalizationType;
        _inputTextField.tintColor = self.colorScheme;
        _inputTextField.delegate = self;
        _inputTextField.backspaceDelegate = self;
        _inputTextField.placeholder = self.placeholderText;
        _inputTextField.accessibilityLabel = self.inputTextFieldAccessibilityLabel ?: NSLocalizedString(@"To", nil);
        _inputTextField.inputAccessoryView = self.inputTextFieldAccessoryView;
        [_inputTextField addTarget:self action:@selector(inputTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    }
    return _inputTextField;
}

- (void)setAutocorrectionType:(UITextAutocorrectionType)autocorrectionType
{
    _autocorrectionType = autocorrectionType;
    [self.inputTextField setAutocorrectionType:self.autocorrectionType];
    [self.invisibleTextField setAutocorrectionType:self.autocorrectionType];
}

- (void)setInputTextFieldKeyboardAppearance:(UIKeyboardAppearance)inputTextFieldKeyboardAppearance
{
    _inputTextFieldKeyboardAppearance = inputTextFieldKeyboardAppearance;
    [self.inputTextField setKeyboardAppearance:self.inputTextFieldKeyboardAppearance];
}

- (void)setInputTextFieldKeyboardType:(UIKeyboardType)inputTextFieldKeyboardType
{
    _inputTextFieldKeyboardType = inputTextFieldKeyboardType;
    [self.inputTextField setKeyboardType:self.inputTextFieldKeyboardType];
}

- (void)setAutocapitalizationType:(UITextAutocapitalizationType)autocapitalizationType
{
    _autocapitalizationType = autocapitalizationType;
    [self.inputTextField setAutocapitalizationType:self.autocapitalizationType];
    [self.invisibleTextField setAutocapitalizationType:self.autocapitalizationType];
}

- (void)inputTextFieldDidChange:(UITextField *)textField
{
    if ([self.delegate respondsToSelector:@selector(tokenField:didChangeText:)]) {
        [self.delegate tokenField:self didChangeText:textField.text];
    }
}

- (void)handleSingleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    [self becomeFirstResponder];
}

- (void)didTapToken:(VENToken *)token
{
    self.exceptCollapse = YES;
    for (VENToken *aToken in self.tokens) {
        if (aToken == token) {
            aToken.highlighted = !aToken.highlighted;
        } else {
            aToken.highlighted = NO;
        }
    }
    [self setCursorVisibility];
}

- (void)unhighlightAllTokens
{
    self.exceptCollapse = NO;
    for (VENToken *token in self.tokens) {
        token.highlighted = NO;
    }
    
    [self setCursorVisibility];
}

- (void)setCursorVisibility
{
    NSArray *highlightedTokens = [self.tokens filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(VENToken *evaluatedObject, NSDictionary *bindings) {
        return evaluatedObject.highlighted;
    }]];
    
    BOOL visible = [highlightedTokens count] == 0;
    if (visible) {
        [self inputTextFieldBecomeFirstResponder];
    } else {
        [self.invisibleTextField becomeFirstResponder];
    }
}

- (void)updateInputTextField
{
    self.inputTextField.placeholder = [self.tokens count] ? nil : self.placeholderText;
}

- (void)focusInputTextField
{
    CGPoint contentOffset = self.scrollView.contentOffset;
    CGFloat targetY = self.inputTextField.y + [self heightForToken] - self.maxHeight;
    if (targetY > contentOffset.y) {
        [self.scrollView setContentOffset:CGPointMake(contentOffset.x, targetY) animated:NO];
    }
}

- (UIColor *)colorSchemeForTokenAtIndex:(NSUInteger)index {
    
    if ([self.dataSource respondsToSelector:@selector(tokenField:colorSchemeForTokenAtIndex:)]) {
        return [self.dataSource tokenField:self colorSchemeForTokenAtIndex:index];
    }
    
    return self.colorScheme;
}

#pragma mark - Data Source

- (VENToken *)tokenField:(VENTokenField *)tokenField tokenAtIndex:(NSUInteger)index {
    if ([self.dataSource respondsToSelector:@selector(tokenField:tokenAtIndex:)]) {
        return [self.dataSource tokenField:self tokenAtIndex:index];
    }
    // return default token with just a configurable title
    VENToken *token = [[VENToken alloc] init];
    NSString *title = [self titleForTokenAtIndex:index];
    [token setTitleText:[NSString stringWithFormat:@"%@,", title]];
    
    return token;
}


- (NSString *)titleForTokenAtIndex:(NSUInteger)index
{
    if ([self.dataSource respondsToSelector:@selector(tokenField:titleForTokenAtIndex:)]) {
        return [self.dataSource tokenField:self titleForTokenAtIndex:index];
    }
    
    return [NSString string];
}

- (NSUInteger)numberOfTokens
{
    if ([self.dataSource respondsToSelector:@selector(numberOfTokensInTokenField:)]) {
        return [self.dataSource numberOfTokensInTokenField:self];
    }
    
    return 0;
}


#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if ([self.delegate respondsToSelector:@selector(tokenField:didEnterText:)]) {
        if ([textField.text length]) {
            [self.delegate tokenField:self didEnterText:textField.text];
        }
    }
    
    return NO;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField == self.inputTextField) {
        [self unhighlightAllTokens];
    }
    if (self.collapsed) {
      [self expand];
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if(textField == self.inputTextField && !self.collapsed && !self.exceptCollapse) {
        [self collapse];
    }
    else {
        self.exceptCollapse = NO;
    }
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    [self unhighlightAllTokens];
    NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    for (NSString *delimiter in self.delimiters) {
        if (newString.length > delimiter.length &&
            [[newString substringFromIndex:newString.length - delimiter.length] isEqualToString:delimiter]) {
            NSString *enteredString = [newString substringToIndex:newString.length - delimiter.length];
            if ([self.delegate respondsToSelector:@selector(tokenField:didEnterText:)]) {
                if (enteredString.length) {
                    [self.delegate tokenField:self didEnterText:enteredString];
                    return NO;
                }
            }
        }
    }
    return YES;
}


#pragma mark - VENBackspaceTextFieldDelegate

- (void)textFieldDidEnterBackspace:(VENBackspaceTextField *)textField
{
    self.exceptCollapse = YES;
    if ([self.delegate respondsToSelector:@selector(tokenField:didDeleteTokenAtIndex:)] && [self numberOfTokens]) {
        BOOL didDeleteToken = NO;
        for (VENToken *token in self.tokens) {
            if (token.highlighted) {
                [self.delegate tokenField:self didDeleteTokenAtIndex:[self.tokens indexOfObject:token]];
                didDeleteToken = YES;
                break;
            }
        }
        if (!didDeleteToken) {
            VENToken *lastToken = [self.tokens lastObject];
            lastToken.highlighted = YES;
        }
        [self setCursorVisibility];
    }
}


@end
