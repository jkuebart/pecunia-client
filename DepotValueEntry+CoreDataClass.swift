//
//  DepotValueEntry+CoreDataClass.swift
//  Pecunia
//
//  Created by Frank Emminghaus on 25.05.21.
//  Copyright © 2021 Frank Emminghaus. All rights reserved.
//
//

import Foundation
import CoreData
import HBCI4Swift

@objc(DepotValueEntry)
public class DepotValueEntry: NSManagedObject {
    public class func createWithHBCIData(balance:HBCICustodyAccountBalance, context:NSManagedObjectContext) -> DepotValueEntry {
        let result = NSEntityDescription.insertNewObject(forEntityName: "DepotValueEntry", into: context) as! DepotValueEntry;
        result.accountNumber = balance.accountNumber;
        result.bankCode = balance.bankCode;
        result.date = balance.date;
        if let depotValue = balance.depotValue {
            result.depotValue = depotValue.value;
            result.depotValueCurrency = depotValue.currency;
        }
        result.prepDate = balance.prepDate;
        let calendar = Calendar.init(identifier: Calendar.Identifier.gregorian);
        let day = calendar.component(Calendar.Component.day, from: balance.date);
        let month = calendar.component(Calendar.Component.month, from: balance.date);
        let year = calendar.component(Calendar.Component.year, from: balance.date);
        result.day = Int32(year*10000 + month*100 + day);
        
        for instrument in balance.instruments {
            result.addToInstruments(Instrument.createWithHBCIData(instrument: instrument, context: context));
        }
        return result;
    }
    
    func depotChange() -> NSDecimalNumber {
        var oldValue = NSDecimalNumber.zero;
        if let instruments = self.instruments {
            for instrument in instruments.allObjects as! [Instrument] {
                if let startPrice = instrument.startPrice, let totalNumber = instrument.totalNumber {
                    oldValue = oldValue.adding(startPrice.multiplying(by: totalNumber));
                }
            }
        }
        if let depotValue = self.depotValue {
            return depotValue.subtracting(oldValue);
        } else {
            return NSDecimalNumber.zero;
        }
    }
    
    public override func value(forKey key: String) -> Any? {
        if key.contains("depotChange") {
            return self.depotChange();
        }
        return super.value(forKey: key);
    }

}
