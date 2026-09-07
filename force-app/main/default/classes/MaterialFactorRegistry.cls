public class MaterialFactorRegistry {
    public enum MaterialType {
        GRID_ELECTRICITY,
        VIRGIN_POLYESTER_PILE,
        SYNTHETIC_RUBBER_BACKING,
        NATURAL_JUTE_BACKING,
        RECYCLED_CARDBOARD,
        MDF_PARTICLE_BOARD,
        RENEWABLE_ELECTRICITY_MIX,
        GENUINE_LEATHER_FABRIC,
        REGULAR_PU_FOAM,
        PLASTIC_POLYBAG_PACKAGING,
        RECYCLED_STEEL_FASTENERS,
        PLASTIC_PACKAGING,
        STEEL_FASTENERS,
        RECYCLED_PET_FIBRE_PILE,
        FSC_CERTIFIED_SOLID_WOOD,
        SOLAR_ENERGY_ON_SITE,
        RECYCLED_PAPER_WRAP,
        VEGAN_LEATHER_PU_RECYCLED_CONTENT,
        HIGH_RESILIENCE_LOW_VOC_FOAM
    }
        
        // Human-readable labels for enum values
        public static final Map<MaterialType, String> LABELS = new Map<MaterialType, String>{
            MaterialType.GRID_ELECTRICITY => 'Grid Electricity',
            MaterialType.VIRGIN_POLYESTER_PILE => 'Virgin Polyester (Pile)',
            MaterialType.SYNTHETIC_RUBBER_BACKING => 'Synthetic Rubber Backing',
            MaterialType.NATURAL_JUTE_BACKING => 'Natural Jute Backing',
            MaterialType.RECYCLED_CARDBOARD => 'Recycled Cardboard',
            MaterialType.MDF_PARTICLE_BOARD => 'MDF / Particle Board',
            MaterialType.RENEWABLE_ELECTRICITY_MIX => 'Renewable Electricity Mix',
            MaterialType.GENUINE_LEATHER_FABRIC => 'Genuine Leather Fabric',
            MaterialType.REGULAR_PU_FOAM => 'Regular PU Foam',
            MaterialType.PLASTIC_POLYBAG_PACKAGING => 'Plastic Polybag Packaging',
            MaterialType.RECYCLED_STEEL_FASTENERS => 'Recycled Steel Fasteners',
            MaterialType.PLASTIC_PACKAGING => 'Plastic Packaging',
            MaterialType.STEEL_FASTENERS => 'Steel Fasteners',
            MaterialType.RECYCLED_PET_FIBRE_PILE => 'Recycled PET Fibre (Pile)',
            MaterialType.FSC_CERTIFIED_SOLID_WOOD => 'FSC-Certified Solid Wood',
            MaterialType.SOLAR_ENERGY_ON_SITE => 'Solar Energy (On-site)',
            MaterialType.RECYCLED_PAPER_WRAP => 'Recycled Paper Wrap',
            MaterialType.VEGAN_LEATHER_PU_RECYCLED_CONTENT => 'Vegan Leather (PU + recycled content)',
            MaterialType.HIGH_RESILIENCE_LOW_VOC_FOAM => 'High-Resilience Low-VOC Foam'
        };
 
        // Emission factors (kg CO2e per unit)
        public static final Map<MaterialType, Decimal> FACTORS = new Map<MaterialType, Decimal>{
            MaterialType.GRID_ELECTRICITY => 0.82,
            MaterialType.VIRGIN_POLYESTER_PILE => 5.5,
            MaterialType.SYNTHETIC_RUBBER_BACKING => 2.8,
            MaterialType.NATURAL_JUTE_BACKING => 0.5,
            MaterialType.RECYCLED_CARDBOARD => 0.1,
            MaterialType.MDF_PARTICLE_BOARD => 1.2,
            MaterialType.RENEWABLE_ELECTRICITY_MIX => 0.2,
            MaterialType.GENUINE_LEATHER_FABRIC => 15,
            MaterialType.REGULAR_PU_FOAM => 8,
            MaterialType.PLASTIC_POLYBAG_PACKAGING => 2.5,
            MaterialType.RECYCLED_STEEL_FASTENERS => 1.2,
            MaterialType.PLASTIC_PACKAGING => 2.5,
            MaterialType.STEEL_FASTENERS => 2.1,
            MaterialType.RECYCLED_PET_FIBRE_PILE => 1.8,
            MaterialType.FSC_CERTIFIED_SOLID_WOOD => 0.45,
            MaterialType.SOLAR_ENERGY_ON_SITE => 0.05,
            MaterialType.RECYCLED_PAPER_WRAP => 0.12,
            MaterialType.VEGAN_LEATHER_PU_RECYCLED_CONTENT => 6.5,
            MaterialType.HIGH_RESILIENCE_LOW_VOC_FOAM => 6
        };
 
 
        public static MaterialType parse(String value) {
            if (String.isBlank(value)) throw new AuraHandledException('Blank material');
            String norm = value.trim();
 
            // Attempt enum name normalization
            String normalizedEnum = norm.replace(' ', '_')
                                        .replace('-', '_')
                                        .replace('(', '')
                                        .replace(')', '')
                                        .replace('/', '_')
                                        .replace('+', ' ')
                                        .toUpperCase();
            try {
                return MaterialType.valueOf(normalizedEnum);
            } catch (Exception ignore) {}
 
            // Attempt label match (case-insensitive)
            for (MaterialType mt : LABELS.keySet()) {
                if (LABELS.get(mt).toLowerCase() == norm.toLowerCase()) {
                    return mt;
                }
            }
            throw new AuraHandledException('Unknown material: ' + value);
        }
 
        public static Decimal getFactor(MaterialType material) {
            return FACTORS.get(material);
        }

    public class MaterialLineRequest {
        @InvocableVariable(required=true)
        public String material; // Label or enum name
 
        @InvocableVariable(required=true)
        public Decimal quantity; // Number of units to multiply by factor
 
        @InvocableVariable
        public String notes;
    }
 
    public class MaterialLineResponse {
        @InvocableVariable
        public String material;
 
        @InvocableVariable
        public Decimal factorKgCO2ePerUnit;
 
        @InvocableVariable
        public Decimal quantity;
 
        @InvocableVariable
        public Decimal emissionKgCO2e;
 
        @InvocableVariable
        public String notes;
 
        @InvocableVariable
        public String message;
    }
 
    public class MaterialAggregateResponse {
        @InvocableVariable
        public List<MaterialLineResponse> lineResults;
 
        @InvocableVariable
        public Decimal totalEmissionKgCO2e;
 
        @InvocableVariable
        public String message;
    }
 
    public class MaterialFlowRequest {
        @InvocableVariable(required=true)
        public List<MaterialLineRequest> items;
    }
 
    /**
     * Flow-invocable entry point: emission = factor (kg CO2e per unit) * quantity
     */
    @InvocableMethod(label='Calculate Material Emissions' description='Calculates carbon emissions (kg CO2e) from material emission factor and quantity.')
    public static List<MaterialAggregateResponse> calculateMaterialsInvocable(List<MaterialFlowRequest> requests) {
        List<MaterialAggregateResponse> outputs = new List<MaterialAggregateResponse>();
        if (requests == null || requests.isEmpty()) {
            MaterialAggregateResponse empty = new MaterialAggregateResponse();
            empty.lineResults = new List<MaterialLineResponse>();
            empty.totalEmissionKgCO2e = 0;
            empty.message = 'No request received.';
            outputs.add(empty);
            return outputs;
        }
 
        MaterialFlowRequest req = requests[0];
        List<MaterialLineRequest> items = (req != null && req.items != null) ? req.items : new List<MaterialLineRequest>();
 
        List<MaterialLineResponse> lineResults = new List<MaterialLineResponse>();
        Decimal total = 0;
        for (MaterialLineRequest item : items) {
            MaterialLineResponse res = calculateMaterialLine(item);
            lineResults.add(res);
            if (res != null && res.emissionKgCO2e != null) {
                total += res.emissionKgCO2e;
            }
        }
 
        MaterialAggregateResponse agg = new MaterialAggregateResponse();
        agg.lineResults = lineResults;
        agg.totalEmissionKgCO2e = total.setScale(6);
        agg.message = 'Calculation completed';
        outputs.add(agg);
        return outputs;
    }
 
    /**
     * Programmatic API
     */
    public static List<MaterialLineResponse> calculateMaterials(List<MaterialLineRequest> items) {
        List<MaterialLineResponse> results = new List<MaterialLineResponse>();
        if (items == null || items.isEmpty()) return results;
        for (MaterialLineRequest item : items) {
            results.add(calculateMaterialLine(item));
        }
        return results;
    }
 
    private static MaterialLineResponse calculateMaterialLine(MaterialLineRequest item) {
        MaterialLineResponse res = new MaterialLineResponse();
        if (item == null) {
            res.message = 'Null line item.';
            return res;
        }
 
        res.material = item.material;
        res.quantity = item.quantity;
        res.notes = item.notes;
 
        // Validate material
        MaterialType mt;
        try {
            mt = MaterialFactorRegistry.parse(item.material);
        } catch (Exception e) {
            res.message = 'Invalid material. ' + e.getMessage();
            return res;
        }
 
        // Validate quantity
        if (item.quantity == null || item.quantity < 0) {
            res.message = 'Quantity must be non-null and non-negative.';
            return res;
        }
 
        Decimal factor = MaterialFactorRegistry.getFactor(mt);
        if (factor == null) {
            res.message = 'Factor not found for material.';
            return res;
        }
 
        res.factorKgCO2ePerUnit = factor;
        res.emissionKgCO2e = (factor * item.quantity).setScale(6);
        res.message = 'OK';
        return res;
    }
}