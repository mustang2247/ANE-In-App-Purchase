//////////////////////////////////////////////////////////////////////////////////////
//
//  Copyright 2012 Freshplanet (http://freshplanet.com | opensource@freshplanet.com)
//  
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//  
//    http://www.apache.org/licenses/LICENSE-2.0
//  
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//  
//////////////////////////////////////////////////////////////////////////////////////

#import "AirInAppPurchase.h"
#import "JSONKit.h"

#define DEFINE_ANE_FUNCTION(fn) FREObject fn(FREContext context, void* functionData, uint32_t argc, FREObject argv[])
#define MAP_FUNCTION(fn, data) { (const uint8_t*)(#fn), (data), &(fn) }

#define INIT_SUCCESSFUL (const uint8_t*)"INIT_SUCCESSFUL"
#define INIT_ERROR (const uint8_t*)"INIT_ERROR"

#define PURCHASE_SUCCESSFUL (const uint8_t*)"PURCHASE_SUCCESSFUL"
#define PURCHASE_ERROR (const uint8_t*)"PURCHASE_ERROR"

#define CONSUME_SUCCESSFUL (const uint8_t*)"CONSUME_SUCCESSFUL"
#define CONSUME_ERROR (const uint8_t*)"CONSUME_ERROR"

#define PRODUCT_INFO_RECEIVED (const uint8_t*)"PRODUCT_INFO_RECEIVED"
#define PRODUCT_INFO_ERROR (const uint8_t*)"PRODUCT_INFO_ERROR"

#define RESTORE_INFO_RECEIVED (const uint8_t*)"RESTORE_INFO_RECEIVED"
#define RESTORE_INFO_ERROR (const uint8_t*)"RESTORE_INFO_ERROR"

@interface AirInAppPurchase () {
    
}

@property (nonatomic, assign) FREContext context;

@end

@implementation AirInAppPurchase

@synthesize context;

- (id)initWithContext:(FREContext)extensionContext {
    
    if (self = [super init]) {
        
        self.context = extensionContext;
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    
    return self;
}

- (void)dealloc {
    
    self.context = nil;
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    
    [super dealloc];
}

#pragma mark - getProductsInfo

- (void)productsRequest:(SKProductsRequest*)request didReceiveResponse:(SKProductsResponse*)response {
    
    NSNumberFormatter* numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    
    NSMutableDictionary* dictionary = [NSMutableDictionary dictionary];
    NSMutableDictionary* productElement = [NSMutableDictionary dictionary];
    
    NSArray* products = response.products;
    
    for (SKProduct* product in products) {
        
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        
        [numberFormatter setLocale:product.priceLocale];
        
        [details setValue:[numberFormatter stringFromNumber:product.price] forKey:@"price"];
        [details setValue:product.localizedTitle forKey:@"title"];
        [details setValue:product.localizedDescription forKey:@"description"];
        [details setValue:product.productIdentifier forKey:@"productId"];
        [details setValue:[numberFormatter currencyCode] forKey:@"price_currency_code"];
        [details setValue:[numberFormatter currencySymbol] forKey:@"price_currency_symbol"];
        [details setValue:product.price forKey:@"value"];
        
        [productElement setObject:details forKey:product.productIdentifier];
    }
    
    [dictionary setObject:productElement forKey:@"details"];
    
    NSString* jsonString = dictionary.JSONString;
    
    if (jsonString != nil)
        FREDispatchStatusEventAsync(context, PRODUCT_INFO_RECEIVED, (const uint8_t*)jsonString.UTF8String);
    else
        FREDispatchStatusEventAsync(context, PRODUCT_INFO_ERROR, (const uint8_t*)"json parse error");
}

- (void)requestDidFinish:(SKRequest*)request {
    FREDispatchStatusEventAsync(context ,(uint8_t*) "DEBUG", (uint8_t*) [@"requestDidFinish" UTF8String] );
}

- (void)request:(SKRequest *)request didFailWithError:(NSError*)error {
    FREDispatchStatusEventAsync(context ,(uint8_t*) "DEBUG", (uint8_t*) [@"requestDidFailWithError" UTF8String] );
}

#pragma mark - makePurchase

- (void)completeTransaction:(SKPaymentTransaction*)transaction {
    
    NSMutableDictionary* data = [NSMutableDictionary dictionary];
    
    SKPayment* payment = transaction.payment;
    NSString* receiptString = [[[NSString alloc] initWithData:transaction.transactionReceipt encoding:NSUTF8StringEncoding] autorelease];
    
    [data setValue:payment.productIdentifier forKey:@"productId"];
    [data setValue:receiptString forKey:@"receipt"];
    [data setValue:@"AppStore" forKey:@"receiptType"];
    
    NSString* jsonString = data.JSONString;
    
    FREDispatchStatusEventAsync(context, PURCHASE_SUCCESSFUL, (const uint8_t*)jsonString.UTF8String);
}

- (void)failedTransaction:(SKPaymentTransaction*)transaction {
    
    NSMutableDictionary* data = [NSMutableDictionary dictionary];

    SKPayment* payment = transaction.payment;
    NSError* error = transaction.error;
    
    [data setValue:[NSNumber numberWithInteger:error.code] forKey:@"code"];
    [data setValue:[error localizedFailureReason] forKey:@"FailureReason"];
    [data setValue:[error localizedDescription] forKey:@"FailureDescription"];
    [data setValue:[error localizedRecoverySuggestion] forKey:@"RecoverySuggestion"];
    
    NSString* jsonString = error.code == SKErrorPaymentCancelled ? @"RESULT_USER_CANCELED" : data.JSONString;
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    
    FREDispatchStatusEventAsync(context, PURCHASE_ERROR, (const uint8_t*)jsonString.UTF8String);
}

- (void)purchasingTransaction:(SKPaymentTransaction*)transaction {
    
    // purchasing transaction
    // dispatch event
    FREDispatchStatusEventAsync(context, (uint8_t*)"PURCHASING", (uint8_t*)
                                [[[transaction payment] productIdentifier] UTF8String]
                                ); 
}

- (void)restoreTransaction:(SKPaymentTransaction*)transaction {
    
    // transaction restored
    // dispatch event
    FREDispatchStatusEventAsync(context, (uint8_t*)"TRANSACTION_RESTORED", (uint8_t*)
                                [[[transaction error] localizedDescription] UTF8String]
                                ); 
    
    
    // conclude the transaction
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)paymentQueue:(SKPaymentQueue*)queue updatedTransactions:(NSArray*)transactions {
    
    NSUInteger nbTransaction = [transactions count];
    NSString* pendingTransactionInformation = [NSString stringWithFormat:@"pending transaction - %@", [NSNumber numberWithUnsignedInteger:nbTransaction]];
    FREDispatchStatusEventAsync(context, (uint8_t*)"UPDATED_TRANSACTIONS", (uint8_t*) [pendingTransactionInformation UTF8String]  );
    
    for (SKPaymentTransaction* transaction in transactions) {
        
        switch (transaction.transactionState) {
                
            case SKPaymentTransactionStatePurchasing:
                [self purchasingTransaction:transaction];
                break;
                
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
                
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
                
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
                break;
                
            case SKPaymentTransactionStateDeferred:
                break;
                
            default:
                FREDispatchStatusEventAsync(context, (uint8_t*)"PURCHASE_UNKNOWN", (uint8_t*) [@"Unknown Reason" UTF8String]);
                break;
        }
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue*)queue {
    FREDispatchStatusEventAsync(context, (uint8_t*)"DEBUG", (uint8_t*) [@"restoreCompletedTransactions" UTF8String] );
}

- (void)paymentQueue:(SKPaymentQueue*)queue restoreCompletedTransactionsFailedWithError:(NSError*)error {
    FREDispatchStatusEventAsync(context, (uint8_t*)"DEBUG", (uint8_t*) [@"restoreFailed" UTF8String] );
}

- (void)paymentQueue:(SKPaymentQueue*)queue removedTransactions:(NSArray *)transactions {
    FREDispatchStatusEventAsync(context, (uint8_t*)"DEBUG", (uint8_t*) [@"removeTransaction" UTF8String] );
}

@end

#pragma mark - ane helpers

NSString* freObjectToNSString(FREObject object) {
    
    uint32_t stringLength;
    const uint8_t* string;
    
    NSString* retString = nil;
    
    if (FREGetObjectAsUTF8(object, &stringLength, &string) == FRE_OK)
        retString = [NSString stringWithUTF8String:(char*)string];
    
    return retString;
}

NSSet* freObjectToNSArrayOfNSString(FREObject object) {
    
    uint32_t arrayLength;
    FREGetArrayLength(object, &arrayLength);
    
    NSMutableSet* retSet = [NSMutableSet set];
    
    for (unsigned int index = 0; index < arrayLength; index++) {
        
        FREObject freString;
        NSString* string = nil;
        
        if (FREGetArrayElementAt(object, index, &freString) == FRE_OK) {

            string = freObjectToNSString(freString);

            if (string != nil)
                [retSet addObject:string];
        }
    }
    
    return retSet;
}

#pragma mark - ane interface

DEFINE_ANE_FUNCTION(initLib) {
    
    // empty on iOS
    return nil;
}

DEFINE_ANE_FUNCTION(getProductsInfo) {
    
    AirInAppPurchase* controller;
    FREGetContextNativeData(context, (void**)&controller);
    
    NSSet* products = freObjectToNSArrayOfNSString(argv[0]);
    
    SKProductsRequest* request = [[SKProductsRequest alloc] initWithProductIdentifiers:products];
    request.delegate = controller;
    
    [request start];
    
    return nil;
}

DEFINE_ANE_FUNCTION(makePurchase) {
    
    NSString* productId = freObjectToNSString(argv[0]);
    
    SKPayment* payment = [SKPayment paymentWithProductIdentifier:productId];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    
    return nil;
}

DEFINE_ANE_FUNCTION(removePurchaseFromQueue) {
    
    NSString* productId = freObjectToNSString(argv[0]);
    
    if (productId == nil) {
        
        FREDispatchStatusEventAsync(context, CONSUME_ERROR, (const uint8_t*)"productId is nil");
        return nil;
    }
    
    NSArray* transactions = [[SKPaymentQueue defaultQueue] transactions];

    for (SKPaymentTransaction* transaction in transactions) {
        
        SKPayment* payment = transaction.payment;
        NSString* transactionProductId = payment.productIdentifier;
        
        if ([transactionProductId isEqualToString:productId]) {
            
            if (transaction.transactionState != SKPaymentTransactionStatePurchased) {
                
                NSString* errMsg = [NSString stringWithFormat:@"transaction state is %ld", (long)transaction.transactionState];
                FREDispatchStatusEventAsync(context, CONSUME_ERROR, (const uint8_t*)errMsg.UTF8String);
            }
            else {
                
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                
                NSError* error;
                NSData* jsonData = [NSJSONSerialization dataWithJSONObject:transaction options:0 error:&error];
                NSString* jsonString = nil;
                
                
                
                FREDispatchStatusEventAsync(context, CONSUME_SUCCESSFUL, NULL);
            }
            
            break;
        }
    }
    
    return nil;
}

#pragma mark - context init

void AirInAppPurchaseContextInitializer(void* extData, const uint8_t* ctxType, FREContext ctx, uint32_t* numFunctionsToTest, const FRENamedFunction** functionsToSet) {
    
    static FRENamedFunction functions[] = {
        MAP_FUNCTION(initLib, NULL),
        MAP_FUNCTION(getProductsInfo, NULL),
        MAP_FUNCTION(makePurchase, NULL),
        MAP_FUNCTION(removePurchaseFromQueue, NULL)
    };
    
    *numFunctionsToTest = sizeof(functionsToSet) / sizeof(FRENamedFunction);
    *functionsToSet = functions;
    
    AirInAppPurchase* controller = [[AirInAppPurchase alloc] initWithContext:ctx];
    FRESetContextNativeData(ctx, (__bridge void *)(controller));
}

void AirInAppPurchaseContextFinalizer(FREContext ctx) {
    
}

#pragma mark - ane init

void AirInAppPurchaseInitializer(void** extDataToSet, FREContextInitializer* ctxInitializerToSet, FREContextFinalizer* ctxFinalizerToSet) {
    
    *extDataToSet = NULL;
    *ctxInitializerToSet = &AirInAppPurchaseContextInitializer;
    *ctxFinalizerToSet = &AirInAppPurchaseContextFinalizer;
}

void AirInAppPurchaseFinalizer(void *extData) {
    
}

