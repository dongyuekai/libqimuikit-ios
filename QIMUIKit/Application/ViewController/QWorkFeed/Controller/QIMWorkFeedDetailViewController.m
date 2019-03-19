//
//  QIMWorkFeedDetailViewController.m
//  QIMUIKit
//
//  Created by lilu on 2019/1/9.
//  Copyright © 2019 QIM. All rights reserved.
//

#import "QIMWorkFeedDetailViewController.h"
#import "QIMWorkMomentCell.h"
#import "QIMWorkMomentModel.h"
#import "QIMWorkMomentContentModel.h"
#import "QIMWorkCommentTableView.h"
#import "QIMWorkCommentInputBar.h"
#import "QIMWorkCommentModel.h"
#import "QIMWorkMomentUserIdentityVC.h"
#import "QIMWorkMomentUserIdentityModel.h"
#import "QIMUUIDTools.h"
#import "QIMMWPhotoBrowser.h"
#import "QIMPhotoBrowserNavController.h"
#import <YYModel/YYModel.h>
#import "LCActionSheet.h"
#import "YYKeyboardManager.h"
#import <Toast/Toast.h>
#import "QIMWorkMomentView.h"
#import "UIApplication+QIMApplication.h"

@interface QIMWorkFeedDetailViewController () <UITableViewDelegate, UITableViewDataSource, QIMWorkCommentTableViewDelegate, QIMWorkCommentInputBarDelegate, UIGestureRecognizerDelegate, MomentCellDelegate, YYKeyboardObserver, MomentViewDelegate>

@property (nonatomic, strong) QIMWorkMomentModel *momentModel;

@property (nonatomic, strong) QIMWorkCommentModel *staticCommentModel;

@property (nonatomic, strong) QIMWorkMomentCell *momentCell;

@property (nonatomic, strong) QIMWorkMomentView *momentView;

@property (nonatomic, strong) QIMWorkCommentTableView *commentListView;

@property (nonatomic, strong) QIMWorkCommentInputBar *commentInputBar;

@property (nonatomic, strong) UIView *maskView;

@property (nonatomic, assign) CGFloat keyboardEndY;

@end

@implementation QIMWorkFeedDetailViewController

#pragma mark - setter and getter

- (QIMWorkMomentModel *)momentModel {
    if (!_momentModel) {
        NSDictionary *momentDic = [[QIMKit sharedInstance] getWorkMomentWithMomentId:self.momentId];
        if (!momentDic.count) {
            [[QIMKit sharedInstance] getRemoteMomentDetailWithMomentUUId:self.momentId withCallback:^(NSDictionary *momentDic) {
                _momentModel = [QIMWorkMomentModel yy_modelWithDictionary:momentDic];
            }];
        } else {
            
        }
        _momentModel = [QIMWorkMomentModel yy_modelWithDictionary:momentDic];
        NSDictionary *contentModelDic = [[QIMJSONSerializer sharedInstance] deserializeObject:[momentDic objectForKey:@"content"] error:nil];
        QIMWorkMomentContentModel *conModel = [QIMWorkMomentContentModel yy_modelWithDictionary:contentModelDic];
        _momentModel.content = conModel;
        _momentModel.isFullText = YES;
    }
    return _momentModel;
}

- (QIMWorkMomentCell *)momentCell {
    if (!_momentCell) {
        _momentCell = [[QIMWorkMomentCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"QIMWorkMomentCell"];
        _momentCell.selectionStyle = UITableViewCellSelectionStyleNone;
        _momentCell.backgroundColor = [UIColor whiteColor];
        _momentCell.delegate = self;
        _momentCell.notShowControl = YES;
        _momentCell.alwaysFullText = YES;
        _momentCell.moment = self.momentModel;
        _momentCell.likeActionHidden = YES;
        _momentCell.commentActionHidden = YES;
        _momentCell.height = self.momentModel.rowHeight;
    }
    return _momentCell;
}

- (QIMWorkMomentView *)momentView {
    if (!_momentView) {
        _momentView = [[QIMWorkMomentView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 20) withMomentModel:self.momentModel];
        _momentView.delegate = self;
    }
    return _momentView;
}

- (QIMWorkCommentTableView *)commentListView {
    if (!_commentListView) {
        _commentListView = [[QIMWorkCommentTableView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, self.view.height - 55 - [[QIMDeviceManager sharedInstance] getHOME_INDICATOR_HEIGHT])];
        _commentListView.backgroundColor = [UIColor whiteColor];
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 300)];
        view.backgroundColor = [UIColor whiteColor];
        _commentListView.commentHeaderView = self.momentView;
        _commentListView.commentDelegate = self;
    }
    _commentListView.commentNum = self.momentModel.commentsNum;
    return _commentListView;
}

- (QIMWorkCommentInputBar *)commentInputBar {
    if (!_commentInputBar) {
        _commentInputBar = [[QIMWorkCommentInputBar alloc] initWithFrame:CGRectMake(0, self.commentListView.bottom, self.view.width, 55 + [[QIMDeviceManager sharedInstance] getHOME_INDICATOR_HEIGHT])];
        _commentInputBar.delegate = self;
    }
    [_commentInputBar setLikeNum:self.momentModel.likeNum withISLike:self.momentModel.isLike];
    [_commentInputBar setMomentId:self.momentModel.momentId];
    return _commentInputBar;
}

- (UIView *)maskView {
    if (!_maskView) {
        _maskView = [[UIView alloc] initWithFrame:self.view.bounds];
        _maskView.backgroundColor = [UIColor clearColor];
        _maskView.alpha = 0.8;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeKeyboard:)];
        tap.numberOfTapsRequired = 1;
        tap.delegate = self;
        [_maskView addGestureRecognizer:tap];
    }
    return _maskView;
}

#pragma mark - life ctyle

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"动态详情";
    if ([[QIMKit sharedInstance] getIsIpad] == YES) {
        [self.view setFrame:CGRectMake(0, 0, [[UIScreen mainScreen] qim_rightWidth], [[UIScreen mainScreen] height])];
    }
    [[YYKeyboardManager defaultManager] addObserver:self];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:19],NSForegroundColorAttributeName:[UIColor qim_colorWithHex:0x333333]}];
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadLocalComments) name:kNotifyReloadWorkComment object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadCommentsAfterUpload:) name:kNotifyReloadWorkComment object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateMomentCommentNum:) name:kNotifyReloadWorkFeedCommentNum object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(beginControlChildCommentWithComment:) name:@"beginControlChildCommentWithComment" object:nil];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage qimIconWithInfo:[QIMIconInfo iconInfoWithText:@"\U0000f3cd" size:20 color:[UIColor qim_colorWithHex:0x333333]]] style:UIBarButtonItemStylePlain target:self action:@selector(backBtnClick:)];

    [self.view addSubview:self.commentListView];
    [self.view addSubview:self.commentInputBar];
    [self loadComments];
    
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (void)backBtnClick:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)updateMomentCommentNum:(NSNotification *)notify {
    NSDictionary *data = notify.object;
    NSString *postId = [data objectForKey:@"postId"];
    if ([postId isEqualToString:self.momentId]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.momentModel.commentsNum = [[data objectForKey:@"postCommentNum"] integerValue];
            [self.commentListView reloadCommentsData];
        });
    }
}

- (void)reloadCommentsAfterUpload:(NSNotification *)notify {
    NSDictionary *uploadCommentModelDic = notify.object;
    QIMWorkCommentModel *uploadCommentModel = [self getCommentModelWithDic:uploadCommentModelDic];
    [self.commentListView reloadUploadCommentWithModel:uploadCommentModel];
}

- (void)loadLocalComments {
    dispatch_async(dispatch_get_main_queue(), ^{
        __weak typeof(self) weakSelf = self;
        [[QIMKit sharedInstance] getWorkCommentWithLastCommentRId:0 withMomentId:self.momentId WithLimit:20 WithOffset:0 withFirstLocalComment:YES WithComplete:^(NSArray * comments) {
            if (comments) {
                [weakSelf.commentListView.commentModels removeAllObjects];
                for (NSDictionary *commentDic in comments) {
                    QIMWorkCommentModel *model = [weakSelf getCommentModelWithDic:commentDic];
                    [weakSelf.commentListView.commentModels addObject:model];
                }
                [weakSelf.commentListView reloadCommentsData];
                [weakSelf.commentListView scrollCommentModelToTopIndex];
            }
        }];
    });
}

- (void)loadComments {

    __weak typeof(self) weakSelf = self;
    [[QIMKit sharedInstance] getRemoteRecentHotCommentsWithMomentId:self.momentId withHotCommentCallBack:^(NSArray *hotComments) {
        if ([hotComments isKindOfClass:[NSArray class]]) {
            [weakSelf.commentListView.hotCommentModels removeAllObjects];
            NSMutableArray *hotCommentIds = [NSMutableArray arrayWithCapacity:3];
            for (NSDictionary *commentDic in hotComments) {
                QIMWorkCommentModel *model = [weakSelf getCommentModelWithDic:commentDic];
                [hotCommentIds addObject:model.commentUUID];
                [weakSelf.commentListView.hotCommentModels addObject:model];
            }
            [[QIMKit sharedInstance] setHotCommentUUIds:hotCommentIds ForMomentId:self.momentId];
            [weakSelf.commentListView reloadCommentsData];
        } else {
            [[QIMKit sharedInstance] setHotCommentUUIds:@[] ForMomentId:self.momentId];
        }
    }];
    [[QIMKit sharedInstance] getRemoteRecentNewCommentsWithMomentId:self.momentId withNewCommentCallBack:^(NSArray *comments) {
        if (comments) {
            [weakSelf.commentListView.commentModels removeAllObjects];
            for (NSDictionary *commentDic in comments) {
                QIMWorkCommentModel *model = [weakSelf getCommentModelWithDic:commentDic];
                [weakSelf.commentListView.commentModels addObject:model];
            }
            [weakSelf.commentListView reloadCommentsData];
        } else {
            [weakSelf.commentListView.commentModels removeAllObjects];
            [weakSelf.commentListView reloadCommentsData];
            [weakSelf.commentListView endRefreshingHeader];
            [weakSelf.commentListView endRefreshingFooterWithNoMoreData];
            
            if (weakSelf.commentListView.commentModels.count <= 0) {
                //没有拉回来热评和普通评论，加载本地
                [self loadLocalComments];
            }
        }
    }];
}

- (QIMWorkCommentModel *)getCommentModelWithDic:(NSDictionary *)momentDic {
    
    QIMWorkCommentModel *model = [QIMWorkCommentModel yy_modelWithDictionary:momentDic];
    return model;
}

- (void)keyboardChangedWithTransition:(YYKeyboardTransition)transition {
    CGRect kbFrame1 = [[YYKeyboardManager defaultManager] convertRect:transition.toFrame toView:self.view];
    CGFloat kbFrameOriginY = CGRectGetMinY(kbFrame1);
    CGFloat kbFrameHeight = CGRectGetHeight(kbFrame1);
    CGRect kbFrame = [[YYKeyboardManager defaultManager] keyboardFrame];
    if (kbFrameOriginY + kbFrameHeight > SCREEN_HEIGHT) {
        //键盘落下
        [UIView animateWithDuration:0.25 animations:^{
            //键盘落下
            self.commentInputBar.frame = CGRectMake(0, self.commentListView.bottom, self.view.width, 55 + [[QIMDeviceManager sharedInstance] getHOME_INDICATOR_HEIGHT]);
            [self.commentInputBar resignFirstInputBar:NO];
            [self.view sendSubviewToBack:self.maskView];
        } completion:nil];
    } else {
        //键盘弹起
        [UIView animateWithDuration:0.25 animations:^{
            self.commentInputBar.frame = CGRectMake(0, kbFrameOriginY - 55, CGRectGetWidth(self.view.frame), 55 + [[QIMDeviceManager sharedInstance] getHOME_INDICATOR_HEIGHT]);
            [self.commentInputBar resignFirstInputBar:YES];
            self.maskView.hidden = NO;
            self.maskView.frame = CGRectMake(0, 0, self.view.width, CGRectGetMinY(self.commentInputBar.frame));
            [self.view addSubview:self.maskView];
            [self.view bringSubviewToFront:self.maskView];
        }];
        [self.commentListView scrollTheTableViewForCommentWithKeyboardHeight:CGRectGetHeight(kbFrame)];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch  {

    // 若为UITableViewCellContentView（即点击了tableViewCell），则不截获Touch事件
    if ([NSStringFromClass([touch.view class]) isEqualToString:@"UITableViewCellContentView"]) {

        return NO;
    }
    return  YES;
}

- (void)closeKeyboard:(UITapGestureRecognizer *)tap {
    [self.view endEditing:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[QIMKit sharedInstance] removeHotCommentUUIdsForMomentId:self.momentId];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

#pragma mark - QIMWorkCommentTableViewDelegate

- (void)beginControlChildCommentWithComment:(NSNotification *)notify {
    dispatch_async(dispatch_get_main_queue(), ^{
//        NSDictionary *postDic = @{@"ChildModel": commentModel, @"ParentIndexPath" : self.parentCommentIndexPath};
        NSDictionary *postDic = notify.object;
        
        QIMWorkCommentModel *commentModel = [postDic objectForKey:@"ChildModel"];
        NSIndexPath *indexPath = [postDic objectForKey:@"ParentIndexPath"];
        self.staticCommentModel = commentModel;
        if ([self.commentInputBar isInputBarFirstResponder] == NO) {
            
            NSString *fromUserId = [NSString stringWithFormat:@"%@@%@", commentModel.fromUser, commentModel.fromHost];
            if ([fromUserId isEqualToString:[[QIMKit sharedInstance] getLastJid]]) {
                //自己实名发的评论
                NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
                [indexSet addIndex:1];
                __weak __typeof(self) weakSelf = self;
                LCActionSheet *actionSheet = [LCActionSheet sheetWithTitle:nil
                                                         cancelButtonTitle:@"取消"
                                                                   clicked:^(LCActionSheet * _Nonnull actionSheet, NSInteger buttonIndex) {
                                                                       __typeof(self) strongSelf = weakSelf;
                                                                       if (!strongSelf) {
                                                                           return;
                                                                       }
                                                                       NSLog(@"buttonIndex : %d", buttonIndex);
                                                                       if (buttonIndex == 1) {
                                                                           //删评论
                                                                           [[QIMKit sharedInstance] deleteRemoteCommentWithComment:commentModel.commentUUID withPostUUId:commentModel.postUUID withSuperParentUUId:commentModel.superParentUUID withCallback:^(BOOL success, NSInteger superStatus) {
                                                                               if (success) {
                                                                                   dispatch_async(dispatch_get_main_queue(), ^{
                                                                                       if (superStatus == 2) {
                                                                                           [strongSelf.commentListView removeCommentWithIndexPath:indexPath withIsHotComment:NO withSuperStatus:superStatus];
                                                                                       }
                                                                                       [[NSNotificationCenter defaultCenter] postNotificationName:@"deleteChildCommentModel" object:commentModel];
                                                                                       [strongSelf.commentListView reloadCommentsData];
                                                                                   });
                                                                               } else {
                                                                                   [[[UIApplication sharedApplication] visibleViewController].view.subviews.firstObject makeToast:@"删除评论失败"];
                                                                               }
                                                                           }];
                                                                       } else if (buttonIndex == 2) {
                                                                           //回复
                                                                           [strongSelf beginAddCommentWithComment:commentModel];
                                                                       }
                                                                   }
                                                     otherButtonTitleArray:@[@"删除", @"回复"]];
                actionSheet.destructiveButtonIndexSet = indexSet;
                actionSheet.destructiveButtonColor = [UIColor qim_colorWithHex:0xF4333C];
                [actionSheet show];
            } else {
                BOOL isAnonymous = [commentModel isAnonymous];
                if (isAnonymous) {
                    NSString *anonymousName = [commentModel anonymousName];
                    NSString *placeholderText = [NSString stringWithFormat:@"  回复 %@", anonymousName];
                    [self.commentInputBar beginCommentToUserId:placeholderText];
                } else {
                    
                    NSString *userId = [NSString stringWithFormat:@"%@@%@", commentModel.fromUser, commentModel.fromHost];
                    NSString *name = [[QIMKit sharedInstance] getUserMarkupNameWithUserId:userId];
                    NSString *placeholderText = [NSString stringWithFormat:@"  回复 %@", name];
                    [self.commentInputBar beginCommentToUserId:placeholderText];
                }
            }
        } else {
            [self.view endEditing:YES];
        }
    });
}

- (void)beginControlCommentWithComment:(QIMWorkCommentModel *)commentModel withIsHotComment:(BOOL)isHotComment withIndexPath:(NSIndexPath *)indexPath {
    self.staticCommentModel = commentModel;
    if (self.staticCommentModel.isDelete == YES) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"该评论已被删除" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
        }];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        if ([self.commentInputBar isInputBarFirstResponder] == NO) {
            
            NSString *fromUserId = [NSString stringWithFormat:@"%@@%@", commentModel.fromUser, commentModel.fromHost];
            if ([fromUserId isEqualToString:[[QIMKit sharedInstance] getLastJid]]) {
                //自己实名发的评论
                NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
                [indexSet addIndex:1];
                __weak __typeof(self) weakSelf = self;
                LCActionSheet *actionSheet = [LCActionSheet sheetWithTitle:nil
                                                         cancelButtonTitle:@"取消"
                                                                   clicked:^(LCActionSheet * _Nonnull actionSheet, NSInteger buttonIndex) {
                                                                       __typeof(self) strongSelf = weakSelf;
                                                                       if (!strongSelf) {
                                                                           return;
                                                                       }
                                                                       NSLog(@"buttonIndex : %d", buttonIndex);
                                                                       if (buttonIndex == 1) {
                                                                           //删评论
                                                                           [[QIMKit sharedInstance] deleteRemoteCommentWithComment:commentModel.commentUUID withPostUUId:commentModel.postUUID withSuperParentUUId:commentModel.superParentUUID withCallback:^(BOOL success, NSInteger superStatus) {
                                                                               if (success) {
                                                                                   [strongSelf.commentListView removeCommentWithIndexPath:indexPath withIsHotComment:isHotComment withSuperStatus:superStatus];
                                                                               } else {
                                                                                   [[[UIApplication sharedApplication] visibleViewController].view.subviews.firstObject makeToast:@"删除评论失败"];
                                                                               }
                                                                           }];
                                                                       } else if (buttonIndex == 2) {
                                                                           //回复
                                                                           [strongSelf beginAddCommentWithComment:commentModel];
                                                                       }
                                                                   }
                                                     otherButtonTitleArray:@[@"删除", @"回复"]];
                actionSheet.destructiveButtonIndexSet = indexSet;
                actionSheet.destructiveButtonColor = [UIColor qim_colorWithHex:0xF4333C];
                [actionSheet show];
            } else {
                BOOL isAnonymous = [commentModel isAnonymous];
                if (isAnonymous) {
                    NSString *anonymousName = [commentModel anonymousName];
                    NSString *placeholderText = [NSString stringWithFormat:@"  回复 %@", anonymousName];
                    [self.commentInputBar beginCommentToUserId:placeholderText];
                } else {
                    
                    NSString *userId = [NSString stringWithFormat:@"%@@%@", commentModel.fromUser, commentModel.fromHost];
                    NSString *name = [[QIMKit sharedInstance] getUserMarkupNameWithUserId:userId];
                    NSString *placeholderText = [NSString stringWithFormat:@"  回复 %@", name];
                    [self.commentInputBar beginCommentToUserId:placeholderText];
                }
            }
        } else {
            [self.view endEditing:YES];
        }
    }
}

- (void)beginAddCommentWithComment:(QIMWorkCommentModel *)commentModel {
    BOOL isAnonymous = [commentModel isAnonymous];
    if (isAnonymous) {
        NSString *anonymousName = [commentModel anonymousName];
        NSString *placeholderText = [NSString stringWithFormat:@"  回复 %@", anonymousName];
        [self.commentInputBar beginCommentToUserId:placeholderText];
    } else {
        
        NSString *userId = [NSString stringWithFormat:@"%@@%@", commentModel.fromUser, commentModel.fromHost];
        NSString *name = [[QIMKit sharedInstance] getUserMarkupNameWithUserId:userId];
        NSString *placeholderText = [NSString stringWithFormat:@"  回复 %@", name];
        [self.commentInputBar beginCommentToUserId:placeholderText];
    }
}

- (void)endAddComment {
    [self.view endEditing:YES];
}

- (void)loadNewComments {
    //下拉刷新
    __weak typeof(self) weakSelf = self;
    [[QIMKit sharedInstance] getRemoteMomentDetailWithMomentUUId:self.momentId withCallback:^(NSDictionary *momentDic) {
        if (momentDic.count > 0) {
            
            weakSelf.momentModel = [QIMWorkMomentModel yy_modelWithDictionary:momentDic];
            NSDictionary *contentModelDic = [[QIMJSONSerializer sharedInstance] deserializeObject:[momentDic objectForKey:@"content"] error:nil];
            QIMWorkMomentContentModel *conModel = [QIMWorkMomentContentModel yy_modelWithDictionary:contentModelDic];
            weakSelf.momentModel.content = conModel;
            weakSelf.momentCell.moment = self.momentModel;
            weakSelf.commentListView.commentNum = self.momentModel.commentsNum;
            [weakSelf.commentListView reloadCommentsData];
            [weakSelf.commentListView endRefreshingHeader];
        }
    }];
    [self loadComments];
}

- (void)loadMoreComments {
    __weak typeof(self) weakSelf = self;
    QIMWorkCommentModel *lastModel = [self.commentListView.commentModels lastObject];
    [[QIMKit sharedInstance] getWorkCommentWithLastCommentRId:lastModel.rId withMomentId:self.momentId WithLimit:20 WithOffset:self.commentListView.commentModels.count withFirstLocalComment:NO WithComplete:^(NSArray * _Nonnull array) {
        NSLog(@"loadMoreComments : %@", array);
        if (array.count > 0) {
            for (NSDictionary *commentDic in array) {
                QIMWorkCommentModel *model = [weakSelf getCommentModelWithDic:commentDic];
                [weakSelf.commentListView.commentModels addObject:model];
            }
            [weakSelf.commentListView reloadCommentsData];
            [weakSelf.commentListView endRefreshingFooter];
        } else {
            [weakSelf.commentListView endRefreshingFooterWithNoMoreData];
        }
    }];
}

#pragma mark - QIMWorkCommentInputBarDelegate

- (void)didaddCommentWithStr:(NSString *)str {
    if (self.staticCommentModel) {
        
        //评论上一条的评论
        NSString *anonymousName = [[QIMWorkMomentUserIdentityManager sharedInstance] anonymousName];
        NSString *anonymousPhoto = [[QIMWorkMomentUserIdentityManager sharedInstance] anonymousPhoto];
        BOOL isAnonymous = [[QIMWorkMomentUserIdentityManager sharedInstance] isAnonymous];
        
        BOOL isToAnonymous = self.staticCommentModel.isAnonymous;
        NSString *toAnonymousName = self.staticCommentModel.anonymousName;
        NSString *toAnonymousPhoto = self.staticCommentModel.anonymousPhoto;
        
        NSMutableDictionary *commentDic = [[NSMutableDictionary alloc] init];
        [commentDic setQIMSafeObject:[NSString stringWithFormat:@"1-%@", [QIMUUIDTools UUID]] forKey:@"commentUUID"];
        [commentDic setQIMSafeObject:self.momentId forKey:@"postUUID"];
        [commentDic setQIMSafeObject:self.staticCommentModel.commentUUID forKey:@"parentCommentUUID"];
        [commentDic setQIMSafeObject:(self.staticCommentModel.superParentUUID.length > 0) ? self.staticCommentModel.superParentUUID : self.staticCommentModel.commentUUID forKey:@"superParentUUID"];
        [commentDic setQIMSafeObject:str forKey:@"content"];
        [commentDic setQIMSafeObject:[QIMKit getLastUserName] forKey:@"fromUser"];
        [commentDic setQIMSafeObject:[[QIMKit sharedInstance] getDomain] forKey:@"fromHost"];
        [commentDic setQIMSafeObject:self.staticCommentModel.fromUser forKey:@"toUser"];
        [commentDic setQIMSafeObject:self.staticCommentModel.fromHost forKey:@"toHost"];
        [commentDic setQIMSafeObject:(isAnonymous == YES) ? @(1) : @(0) forKey:@"isAnonymous"];
        [commentDic setQIMSafeObject:(anonymousPhoto.length > 0) ? anonymousPhoto : @"" forKey:@"anonymousPhoto"];
        [commentDic setQIMSafeObject:(anonymousName.length > 0) ? anonymousName : @"" forKey:@"anonymousName"];
        [commentDic setQIMSafeObject:(isToAnonymous == YES) ? @(1) : @(0) forKey:@"toisAnonymous"];
        [commentDic setQIMSafeObject:(toAnonymousName.length > 0) ? toAnonymousName : toAnonymousName forKey:@"toAnonymousName"];
        [commentDic setQIMSafeObject:(toAnonymousPhoto.length > 0) ? toAnonymousPhoto : toAnonymousPhoto forKey:@"toAnonymousPhoto"];
        [commentDic setQIMSafeObject:self.momentModel.ownerId forKey:@"postOwner"];
        [commentDic setQIMSafeObject:self.momentModel.ownerHost forKey:@"postOwnerHost"];
        [commentDic setQIMSafeObject:[[QIMKit sharedInstance] getHotCommentUUIdsForMomentId:self.momentId] forKey:@"hotCommentUUID"];

        [[QIMKit sharedInstance] uploadCommentWithCommentDic:commentDic];
    } else {
        //评论帖子
        NSString *anonymousName = [[QIMWorkMomentUserIdentityManager sharedInstance] anonymousName];
        NSString *anonymousPhoto = [[QIMWorkMomentUserIdentityManager sharedInstance] anonymousPhoto];
        BOOL isAnonymous = [[QIMWorkMomentUserIdentityManager sharedInstance] isAnonymous];
        
        NSMutableDictionary *commentDic = [[NSMutableDictionary alloc] init];
        [commentDic setQIMSafeObject:[NSString stringWithFormat:@"1-%@", [QIMUUIDTools UUID]] forKey:@"commentUUID"];
        [commentDic setQIMSafeObject:self.momentId forKey:@"postUUID"];
        [commentDic setQIMSafeObject:str forKey:@"content"];
        [commentDic setQIMSafeObject:[QIMKit getLastUserName] forKey:@"fromUser"];
        [commentDic setQIMSafeObject:[[QIMKit sharedInstance] getDomain] forKey:@"fromHost"];
        [commentDic setQIMSafeObject:@"" forKey:@"toUser"];
        [commentDic setQIMSafeObject:@"" forKey:@"toHost"];
        [commentDic setQIMSafeObject:(isAnonymous == YES) ? @(1) : @(0) forKey:@"isAnonymous"];
        [commentDic setQIMSafeObject:(anonymousPhoto.length > 0) ? anonymousPhoto : @"" forKey:@"anonymousPhoto"];
        [commentDic setQIMSafeObject:(anonymousName.length > 0) ? anonymousName : @"" forKey:@"anonymousName"];
        [commentDic setQIMSafeObject:@(0) forKey:@"toisAnonymous"];
        [commentDic setQIMSafeObject:@"" forKey:@"toAnonymousName"];
        [commentDic setQIMSafeObject:@"" forKey:@"toAnonymousPhoto"];
        [commentDic setQIMSafeObject:self.momentModel.ownerId forKey:@"postOwner"];
        [commentDic setQIMSafeObject:self.momentModel.ownerHost forKey:@"postOwnerHost"];
        [commentDic setQIMSafeObject:[[QIMKit sharedInstance] getHotCommentUUIdsForMomentId:self.momentId] forKey:@"hotCommentUUID"];
        [[QIMKit sharedInstance] uploadCommentWithCommentDic:commentDic];
    }
    //回复完之后清空staticCommentModel
    self.staticCommentModel = nil;
}

- (void)dealloc {
    [[QIMWorkMomentUserIdentityManager sharedInstance] setIsAnonymous:NO];
    [[QIMWorkMomentUserIdentityManager sharedInstance] setAnonymousName:nil];
    [[QIMWorkMomentUserIdentityManager sharedInstance] setAnonymousPhoto:nil];
    [[YYKeyboardManager defaultManager] removeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didOpenUserIdentifierVC {
    QIMWorkMomentUserIdentityVC *identityVc = [[QIMWorkMomentUserIdentityVC alloc] init];
    identityVc.momentId = self.momentId;
    [self.navigationController pushViewController:identityVc animated:YES];
}

// 查看全文/收起
- (void)didSelectFullText:(QIMWorkMomentCell *)cell withFullText:(BOOL)isFullText {
    
}

- (void)didClickSmallImage:(QIMWorkMomentModel *)model WithCurrentTag:(NSInteger)tag {
    //初始化图片浏览控件
    QIMMWPhotoBrowser *browser = [[QIMMWPhotoBrowser alloc] initWithDelegate:self];
    browser.displayActionButton = NO;
    browser.zoomPhotosToFill = YES;
    browser.enableSwipeToDismiss = NO;
    [browser setCurrentPhotoIndex:tag];
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_7_0
    browser.wantsFullScreenLayout = YES;
#endif
    
    //初始化navigation
    QIMPhotoBrowserNavController *nc = [[QIMPhotoBrowserNavController alloc] initWithRootViewController:browser];
    nc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:nc animated:YES completion:nil];
}

#pragma mark - QIMMWPhotoBrowserDelegate

- (NSUInteger)numberOfPhotosInPhotoBrowser:(QIMMWPhotoBrowser *)photoBrowser {
    
    return self.momentModel.content.imgList.count;
}

- (id <QIMMWPhoto>)photoBrowser:(QIMMWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    
    if (index > self.momentModel.content.imgList.count) {
        return nil;
    }
    QIMWorkMomentPicture *picture = [self.momentModel.content.imgList objectAtIndex:index];
    NSString *imageUrl = picture.imageUrl;
    if (![imageUrl qim_hasPrefixHttpHeader] && imageUrl.length > 0) {
        imageUrl = [NSString stringWithFormat:@"%@/%@", [[QIMKit sharedInstance] qimNav_InnerFileHttpHost], imageUrl];
    } else {
        
    }
    if (imageUrl.length > 0) {
        NSURL *url = [NSURL URLWithString:[imageUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        return url ? [[QIMMWPhoto alloc] initWithURL:url] : nil;
    } else {
        return nil;
    }
}

- (void)photoBrowserDidFinishModalPresentation:(QIMMWPhotoBrowser *)photoBrowser {
    //界面消失
    [photoBrowser dismissViewControllerAnimated:YES completion:^{
        //tableView 回滚到上次浏览的位置
    }];
}

@end
