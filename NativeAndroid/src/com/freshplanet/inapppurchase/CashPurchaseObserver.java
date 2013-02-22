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

package com.freshplanet.inapppurchase;

import android.os.Handler;
import android.util.Log;

import com.freshplanet.inapppurchase.BillingService.RequestPurchase;
import com.freshplanet.inapppurchase.BillingService.RestoreTransactions;
import com.freshplanet.inapppurchase.Consts.PurchaseState;
import com.freshplanet.inapppurchase.Consts.ResponseCode;

public class CashPurchaseObserver extends PurchaseObserver {

    public CashPurchaseObserver(Handler handler) {
        super(Extension.context.getActivity(), handler);
    }

	
	private static String TAG = "CashPurchaseObserver";
	
	@Override
	public void onBillingSupported(boolean supported, String type) {
		Log.d(TAG, "onBillingSupported");
		if (supported)
		{
			if (type != null)
			{
				Log.d(TAG, "supported "+type);
				Extension.context.dispatchStatusEventAsync("PURCHASE_ENABLED", type);
			} else
			{
				Log.d(TAG, "supported");
				Extension.context.dispatchStatusEventAsync("PURCHASE_ENABLED", "Yes");
			}
		} else
		{
			if (type != null)
			{
				Log.d(TAG, "unsupported "+type);

				Extension.context.dispatchStatusEventAsync("PURCHASE_DISABLED", type);

			} else
			{
				Log.d(TAG, "unsupported ");
				Extension.context.dispatchStatusEventAsync("PURCHASE_DISABLED", "Yes");
			}
		}
	}

	@Override
	public void onPurchaseStateChange(PurchaseState purchaseState,
			String itemId, int quantity, long purchaseTime,
			String developerPayload) {
		Log.d(TAG, "onPurchaseStateChange");
	}

	@Override
	public void onRequestPurchaseResponse(RequestPurchase request,
			ResponseCode responseCode) {
		Log.d(TAG, "onRequestPurchaseResponse");
		
		if (responseCode != Consts.ResponseCode.RESULT_OK && responseCode != Consts.ResponseCode.RESULT_USER_CANCELED)
		{
			Extension.context.dispatchStatusEventAsync("PURCHASE_ERROR", responseCode.toString());
		}
		
	}

	@Override
	public void onRestoreTransactionsResponse(RestoreTransactions request,
			ResponseCode responseCode) {
		Log.d(TAG, "onRestoreTransactionsResponse");
	}


}
