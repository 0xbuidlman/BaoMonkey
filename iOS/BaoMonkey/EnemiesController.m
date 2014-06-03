//
//  EnemiesController.m
//  BaoMonkey
//
//  Created by Rémi Hillairet on 07/05/2014.
//  Copyright (c) 2014 BaoMonkey. All rights reserved.
//

#import "EnemiesController.h"
#import "LamberJack.h"
#import "Hunter.h"
#import "Climber.h"
#import "GameData.h"
#import "Define.h"
#import "PreloadData.h"
#import "BaoSize.h"

@implementation EnemiesController

@synthesize enemies;

-(id)initWithScene:(SKScene*)_scene {
    self = [super init];
    if (self) {
        enemies = [[NSMutableArray alloc] init];
        scene = _scene;
        timeForAddLamberJack = 0;
        timeForAddHunter = 0;
        timeForAddClimber = 0;
        numberOfFloors = 0;
        numberHunter = 0;
        numberClimber = 0;
        [self initChoppingSlots];
        [self initFloorsPosition];
    }
    return self;
}

-(void)initChoppingSlots {
    choppingSlots = [[NSMutableArray alloc] init];
    CGFloat spaceDistance;
    CGSize lamberSize = [BaoSize lamberJack];
    
    spaceDistance = lamberSize.width;
    for (int i = 0; i < 3 ; i++) {
        NSMutableDictionary *tmp = [[NSMutableDictionary alloc]
                                    initWithObjectsAndKeys:@"FREE", @"LEFT", @"FREE", @"RIGHT",
                                    [[NSNumber alloc]
                                     initWithFloat:(spaceDistance + (spaceDistance * i))], @"posX", nil];
        [choppingSlots addObject:tmp];
    }
}

#pragma mark - Enemy Controller

-(Direction)chooseDirection {
    NSUInteger numberLeft = 0;
    NSUInteger numberRight = 0;
    
    for (Enemy *enemy in enemies) {
        if (enemy.type == EnemyTypeLamberJack) {
            if (enemy.direction == LEFT)
                numberLeft++;
            else if (enemy.direction == RIGHT)
                numberRight++;
        }
    }
    if (numberRight == numberLeft)
        return arc4random() % 2 ? LEFT : RIGHT;
    else if (numberRight < numberLeft)
        return RIGHT;
    return LEFT;
}

-(void)addLamberJack {
    LamberJack *newLamberJack;
    
    newLamberJack = [[LamberJack alloc] initWithDirection:[self chooseDirection]];

    [enemies addObject:newLamberJack];
    [scene addChild:newLamberJack.node];
}

-(void)addClimber {
    Climber *newClimber;
    
    if (rand() % 2 == 1)
        newClimber = [[Climber alloc] initWithDirection:LEFT];
    else
        newClimber = [[Climber alloc] initWithDirection:RIGHT];
    
    [enemies addObject:newClimber];
    [scene addChild:newClimber.node];
}

-(void)addHunter {
    Hunter *newHunter;
    int hunterFloor = rand() % self->numberOfFloors + 1;
    int positionHunterInSlot = 0;

    for (int currentSlot = 0; currentSlot < self->numberOfFloors; currentSlot++) {
        if (((positionHunterInSlot = [self checkPositionFloorSlot:hunterFloor - 1])) != -1)
            break;
    }
    if (positionHunterInSlot == -1)
        return ;
    
    newHunter = [[Hunter alloc] initWithFloor:hunterFloor
                                         slot:positionHunterInSlot];
    
    [enemies addObject:newHunter];
    [scene addChild:newHunter.node];
}

-(NSUInteger)countOfEnemyType:(EnemyType)_type
{
    NSUInteger count = 0;
    
    for (Enemy *enemy in enemies) {
        if (enemy.type == _type)
            count++;
    }
    return count;
}

-(void)updateEnemies:(CFTimeInterval)currentTime {
    if ([self countOfEnemyType:EnemyTypeLamberJack] < MAX_LUMBERJACK && ((timeForAddLamberJack <= currentTime) || (timeForAddLamberJack == 0))) {
        float randomFloat = (MIN_NEXT_ENEMY + ((float)arc4random() / (0x100000000 / (MAX_NEXT_ENEMY - MIN_NEXT_ENEMY))));
        [self addLamberJack];
        timeForAddLamberJack = currentTime + randomFloat;
    }
    
    if ([GameData getLevel] >= 1)
    {
        if ([GameData getLevel] % 2 == 0) {
            if ((numberOfFloors == 0 || numberOfFloors * 2 < [GameData getLevel])) {
                [self addFloor];
                numberHunter += 1;
            }
        }

        if ([GameData getLevel] > 2) {
            if ([GameData getLevel] / 2 % 2 == 0)
                numberClimber = (int)[GameData getLevel] / 2;
        }
        
        
        if ([self countOfEnemyType:EnemyTypeClimber] < numberClimber && ((timeForAddClimber <= currentTime) || (timeForAddClimber == 0))){
            float randomFloat = (8.5 + ((float)arc4random() / (0x100000000 / (3.0 + 2 - 2.5))));
            [self addClimber];
            timeForAddClimber = currentTime + randomFloat;
        }
        
        if (numberOfFloors > 0 &&
            [self countOfEnemyType:EnemyTypeHunter] < numberHunter && ((timeForAddHunter <= currentTime) || (timeForAddHunter == 0))){
            float randomFloat = (MIN_NEXT_ENEMY + ((float)arc4random() / (0x100000000 / (MAX_NEXT_ENEMY - MIN_NEXT_ENEMY))));
            [self addHunter];
            timeForAddHunter = currentTime + randomFloat;
        }
    }
    
    for (Enemy *enemy in enemies) {
        if (enemy.type == EnemyTypeLamberJack)
            [(LamberJack*)enemy updatePosition:choppingSlots];
    }
}

-(void)deleteEnemy:(Enemy*)enemy {
    SKAction *fadeIn = [SKAction fadeAlphaTo:1.0 duration:0.25];
    SKAction *sound = [PreloadData getDataWithKey:DATA_COCONUT_SOUND];
    
    [enemy.node runAction: [SKAction sequence:@[fadeIn, sound]]completion:^{
        [enemy.node removeFromParent];
    }];
    
    if (enemy.type == EnemyTypeLamberJack) {
        LamberJack *lamber;
        lamber = (LamberJack*)enemy;
        [lamber stopChopping];
        [lamber freeTheSlot:choppingSlots];
        [lamber startDead];
        [GameData addPointToScore:10];
    }
    else if (enemy.type == EnemyTypeHunter) {
        Hunter *hunter = (Hunter *)enemy;
        self->slotFloor[hunter.floor - 1] -= 1 << hunter.slot;
        [hunter startDead];
        [GameData addPointToScore:20];
    }
    [enemies removeObject:enemy];
}

#pragma mark - Floor Controller

-(void)addFloor {
    CGRect screen = [UIScreen mainScreen].bounds;
    SKAction *slide;
    
    if (numberOfFloors >= MAX_FLOOR)
        return ;
    numberOfFloors++;
    SKSpriteNode *floor = [SKSpriteNode spriteNodeWithTexture:[PreloadData getDataWithKey:DATA_PLATEFORM] size:[BaoSize plateform]];
    if (numberOfFloors % 2 != 0)
    {
        floor.xScale = -1;
        floor.position = CGPointMake(-(FLOOR_WIDTH / 2), [[floorsPosition objectAtIndex:numberOfFloors - 1] doubleValue]);
        slide = [SKAction moveToX:(floor.size.width / 2) duration:0.5];
    }
    else
    {
        floor.xScale = 1;
        floor.position = CGPointMake(screen.size.width + (FLOOR_WIDTH / 2), [[floorsPosition objectAtIndex:numberOfFloors - 1] doubleValue]);
        slide = [SKAction moveToX:(screen.size.width - (floor.size.width / 2)) duration:0.5];
    }
    [scene addChild:floor];
    [floor runAction:slide];
}

#pragma mark - Floor Slot management

-(void)initFloorsPosition {
    NSMutableArray *positions;
    
    positions = [[NSMutableArray alloc] init];
    for (int i = 0 ; i < MAX_FLOOR ; i++) {
        CGFloat posY = MIN_POSY_FLOOR + (SPACE_BETWEEN * i) - 22;
        [positions addObject:[NSNumber numberWithDouble:posY]];
    }
    floorsPosition = [[NSArray alloc] initWithArray:positions];
}

-(void)initFloorSlot {
    for (int index = 0; index < MAX_FLOOR; index++) {
        self->slotFloor[index] = 0;
    }
}

-(int)checkPositionFloorSlot:(NSInteger)floor {
    if (floor < MAX_FLOOR) {
        for (int rank = 3; rank >= 0; rank--) {
            if ((self->slotFloor[floor] >> rank & 0x1) == 0) {
                self->slotFloor[floor] += 1 << rank;
                return (rank + 1);
            }
        }
    }
    return (-1);
}

@end
