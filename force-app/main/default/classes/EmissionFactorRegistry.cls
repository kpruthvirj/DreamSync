public class EmissionFactorRegistry {
 
    public enum EmissionMode {
        ROAD, SEA, AIR
    }
    public enum QuantityUnit {
        KG, TON
    }
    public enum DistanceUnit {
        KM, MI
    }
     
    private static final Decimal ROAD_FACTOR = 0.1;
    private static final Decimal SEA_FACTOR  = 0.015;
    private static final Decimal AIR_FACTOR  = 0.6;

    private static final Decimal KG_PER_TON = 1000;
    private static final Decimal KM_PER_MI = 1.60934;

    public static Decimal getFactorKgPerTonKm(EmissionMode mode) {
      switch on mode {
                when ROAD { return ROAD_FACTOR; }
                when SEA  { return SEA_FACTOR; }
                when AIR  { return AIR_FACTOR; }
            }
            return null;
    }

    public static Decimal toTons(Decimal quantity, QuantityUnit unit) {
            if (quantity == null) return null;
            if (unit == QuantityUnit.TON) return quantity;
            if (unit == QuantityUnit.KG) {
                return (quantity / KG_PER_TON);
            }
            return null;
    }

    public static Decimal toKm(Decimal distance, DistanceUnit unit) {
            if (distance == null) return null;
            if (unit == DistanceUnit.KM) return distance;
            if (unit == DistanceUnit.MI) {
                return (distance * KM_PER_MI);
            }
            return null;
    }
 

    public class LineItemRequest {
        @InvocableVariable(required=true)
        public String transportMode; // ROAD, SEA, AIR

        @InvocableVariable(required=true)
        public Decimal quantity; // numeric value

        @InvocableVariable(required=true)
        public String quantityUnit; // KG or TON

        @InvocableVariable(required=true)
        public Decimal distance; // numeric value

        @InvocableVariable(required=true)
        public String distanceUnit; // KM or MI
    }

    public class LineItemResponse {
        @InvocableVariable
        public String transportMode;

        @InvocableVariable
        public Decimal quantity;

        @InvocableVariable
        public String quantityUnit;

        @InvocableVariable
        public Decimal distance;

        @InvocableVariable
        public String distanceUnit;

        @InvocableVariable
        public Decimal emissionKgCO2e; // computed emissions in kg CO2e

        @InvocableVariable
        public Decimal factorKgPerTonKm; // factor used

        @InvocableVariable
        public String message; // validation or info message
    }

    public class AggregateResponse {
         @InvocableVariable
         public List<LineItemResponse> lineResults;

        @InvocableVariable
        public Decimal totalEmissionKgCO2e;

        @InvocableVariable
        public String message;
    }

    public class FlowRequest {
        @InvocableVariable(required=true)
        public List<LineItemRequest> items;
    }

    @InvocableMethod(label='Calculate Carbon Emissions' description='Calculates carbon emissions (kg CO2e) for materials/products by transport mode, quantity and distance with unit conversions.')
    public static List<AggregateResponse> calculateInvocable(List<FlowRequest> requests) {
        List<AggregateResponse> outputs = new List<AggregateResponse>();
        if (requests == null || requests.isEmpty()) {
            AggregateResponse empty = new AggregateResponse();
            empty.lineResults = new List<LineItemResponse>();
            empty.totalEmissionKgCO2e = 0;
            empty.message = 'No request received.';
            outputs.add(empty);
            return outputs;
        }

        FlowRequest req = requests[0];
        List<LineItemRequest> items = (req != null && req.items != null) ? req.items : new List<LineItemRequest>();

        List<LineItemResponse> lineResults = new List<LineItemResponse>();
        Decimal total = 0;
        for (LineItemRequest item : items) {
            LineItemResponse res = calculateLine(item);
            lineResults.add(res);
            if (res != null && res.emissionKgCO2e != null) {
                total += res.emissionKgCO2e;
            }
        }

        AggregateResponse agg = new AggregateResponse();
        agg.lineResults = lineResults;
        agg.totalEmissionKgCO2e = total;
        agg.message = 'Calculation completed';
        outputs.add(agg);
        return outputs;
    }

    public static List<LineItemResponse> calculate(List<LineItemRequest> items) {
        List<LineItemResponse> results = new List<LineItemResponse>();
        if (items == null || items.isEmpty()) {
            return results;
        }
        for (LineItemRequest item : items) {
            results.add(calculateLine(item));
        }
        return results;
    }

    private static LineItemResponse calculateLine(LineItemRequest item) {
        LineItemResponse res = new LineItemResponse();
        if (item == null) {
            res.message = 'Null line item.';
            return res;
        }

        res.transportMode = item.transportMode;
        res.quantity = item.quantity;
        res.quantityUnit = item.quantityUnit;
        res.distance = item.distance;
        res.distanceUnit = item.distanceUnit;
      
        // Validate transport mode
        EmissionMode mode;
        try {
            mode = parseMode(item.transportMode);
        } catch (Exception e) {
            res.message = 'Invalid transport mode. Expected ROAD, SEA, or AIR.';
            return res;
        }

        // Validate quantity and distance
        if (item.quantity == null || item.quantity < 0) {
            res.message = 'Quantity must be non-null and non-negative.';
            return res;
        }
        if (item.distance == null || item.distance < 0) {
            res.message = 'Distance must be non-null and non-negative.';
            return res;
        }

        QuantityUnit qUnit;
        try {
            qUnit = parseQuantityUnit(item.quantityUnit);
        } catch (Exception ex) {
            res.message = 'Invalid quantity unit. Expected KG or TON.';
            return res;
        }

        DistanceUnit dUnit;
        try {
            dUnit = parseDistanceUnit(item.distanceUnit);
        } catch (Exception ex) {
            res.message = 'Invalid distance unit. Expected KM or MI.';
            return res;
        }

        // Normalize to tons and km
        Decimal tons = EmissionFactorRegistry.toTons(item.quantity, qUnit);
        Decimal km = EmissionFactorRegistry.toKm(item.distance, dUnit);

        // Resolve factor (kg CO2e per ton-km)
        Decimal factor = EmissionFactorRegistry.getFactorKgPerTonKm(mode);
        res.factorKgPerTonKm = factor;

        // Compute emissions in kg CO2e
        // emission = factor * tons * km
        if (tons == null || km == null || factor == null) {
            res.message = 'Normalization or factor resolution failed.';
            return res;
        }

        Decimal emission = (factor * tons * km);
        // Round to 6 decimal places for stability; adjust if needed
        res.emissionKgCO2e = emission.setScale(6);

        res.message = 'OK';
        return res;
    }

    private static EmissionMode parseMode(String val) {
        if (String.isBlank(val)) throw new AuraHandledException('Blank mode');
        String norm = val.trim().toUpperCase();
        return EmissionMode.valueOf(norm);
    }

    private static QuantityUnit parseQuantityUnit(String val) {
        if (String.isBlank(val)) throw new AuraHandledException('Blank quantity unit');
        String norm = val.trim().toUpperCase();
        return QuantityUnit.valueOf(norm);
    }

    private static DistanceUnit parseDistanceUnit(String val) {
        if (String.isBlank(val)) throw new AuraHandledException('Blank distance unit');
        String norm = val.trim().toUpperCase();
        return DistanceUnit.valueOf(norm);
    }
 }