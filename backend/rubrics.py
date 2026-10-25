"""Rubrics from the updated environment, labour, and animal ethicality PDFs.

Category weights are fractions of the dimension's performance score.
Questions have equal weight within a category unless specified below.
The weighted Transparency categories are separate from evidence coverage.
"""


ENVIRONMENTAL_RUBRIC: dict[str, float] = {
    "emissions": 0.20,
    "renewability": 0.15,
    "deforestation": 0.15,
    "water": 0.10,
    "materials": 0.10,
    "waste": 0.10,
    "chemicals": 0.10,
    "transparency": 0.10,
}

ENVIRONMENTAL_QUESTIONS: dict[str, list[str]] = {
    "emissions": [
        "Does the company measure its greenhouse gas emissions in accordance with a recognized standard, such as the GHG Protocol or ISO 14064-1?",
        "Does it prioritize direct emissions reductions and avoid relying heavily on carbon credits?",
        "Does it have measurable, independently validated emissions-reduction targets?",
        "Does it report measurable progress toward reducing emissions?",
        "Is its emissions data independently audited or verified?",
    ],
    "renewability": [
        "Does the company, its facilities, and suppliers mostly use renewable sources of energy?",
        "Does the company, its facilities, and suppliers mostly use renewable materials?",
        "Does the company, its facilities, and suppliers sustainably replenish the renewable materials they use?",
        "Does the company publish measurable goals towards replacing its nonrenewable energy and materials with renewable sources?",
        "Has the company reported progress towards their goals of having more renewable energy and materials?",
    ],
    "deforestation": [
        "Does the company avoid deforestation-risk materials or publicly identify and responsibly manage any such materials it uses?",
        "Does the company have a deforestation-free sourcing policy?",
        "Do the countries, farms, forests, mills, tanneries, and/or suppliers connected to the company's materials minimize deforestation?",
        "Does it have relevant third-party certifications such as FSC?",
        "If the company has measurable deadlines for eliminating deforestation-linked sourcing, does it report progress toward those deadlines?",
        "Is the company free of substantiated, unresolved links to deforestation or habitat destruction?",
    ],
    "water": [
        "Does the company avoid excessive and unnecessary use of water in its facilities?",
        "Does the company publish measurable water-reduction targets?",
        "Does it report progress toward those water-reduction targets?",
        "Does the company mandate its facilities to treat and test its wastewater?",
    ],
    "materials": [
        "Does the company and its facilities use mostly recycled and otherwise lower-impact materials?",
        "Does the company and its facilities use mostly organic materials?",
        "Does the company have targets for increasing the use of lower-impact materials (if applicable), and has it made measurable progress towards them?",
        "Does the company and its facilities avoid the use of virgin synthetic materials?",
        "Does the company minimize its use of polyester, nylon, acrylic, elastane, and similar materials?",
        "Does the company have targets for decreasing the use of virgin synthetic materials (if applicable), and has it made measurable progress towards them?",
        "Does the company mitigate microplastic pollution from its products, textile or otherwise?",
    ],
    "waste": [
        "Does it separate hazardous and non-hazardous waste?",
        "If the company publishes measurable waste-reduction targets, does it report progress toward those targets?",
        "Does it manage unsold or returned products in a sustainable fashion according to third party certifications such as B Corp or Cradle to Cradle?",
        "Does the company avoid destroying or incinerating unsold products?",
        "Does it have repair, resale, rental, reuse, donation, or take-back programs?",
        "Does it design products for durability, recycling, or disassembly?",
        "Does it track waste and unsold inventory through its supply chain?",
        "Does it have a credible zero-waste or landfill-diversion certification?",
    ],
    "chemicals": [
        "Does it publish or follow a Manufacturing Restricted Substances List, or MRSL?",
        "Does it test finished products for restricted chemicals?",
        "Does it test factory wastewater for hazardous chemicals?",
        "Does it have measurable targets for eliminating harmful chemicals?",
        "Does it audit suppliers for chemical compliance?",
        "Does it explain and enforce consequences when a supplier violates its chemical rules?",
        "Are most of the company's chemical-management claims independently verified?",
        "Does the company restrict the use of chemicals known to be harmful specifically to children and/or infants?",
        "Has this company been historically uninvolved in superfund cleanup sites?",
        "Does the company mitigate its use of forever chemicals, such as PFAS?",
        "Has the company been free of health-related lawsuits for its products?",
    ],
    "transparency": [
        "Does the company publish its total water withdrawal or consumption?",
        "Does the company publish the material breakdown of its products?",
        "Does the company publish its own emission data?",
        "Does the company publish its own deforestation data?",
        "Does the company publish its total waste produced?",
        "Does the company publish its use of chemicals and address appropriate chemical-related safety concerns?",
    ],
}


ETHICAL_LABOR_RUBRIC: dict[str, float] = {
    "forced_labor": 0.175,
    "child_labor": 0.15,
    "wages_and_benefits": 0.175,
    "health_and_safety": 0.15,
    "association": 0.05,
    "grievances": 0.05,
    "working_hours_and_job_security": 0.10,
    "equality_and_harassment": 0.10,
    "transparency": 0.05,
}

ETHICAL_LABOR_QUESTIONS: dict[str, list[str]] = {
    "forced_labor": [
        "Are workers free to terminate their employment without facing any forms of retaliation or intimidation?",
        "Are there no recruitment fees required for a person to secure a job at the company?",
        "Do the company's workers have unrestricted access to their passports/visas/travel documents?",
    ],
    "child_labor": [
        "Does the company enforce mandatory age-screening to verify that their employees are of the minimum age before hiring them?",
        "Do the company's contracts legally mandate that partners comply with international Fair Labor Association (FLA) or local laws?",
        "Does the company deploy unannounced, third-party monitoring to audit manufacturing plants, agricultural sites, and subcontractors?",
    ],
    "wages_and_benefits": [
        "Is this company currently certified as a Living Wage Employer by an independent third party, such as the Living Wage Foundation or an accredited local equivalent?",
        "Has this company been free of any government, legal, or third party alerts for delayed pay or wrong wages over the last three years?",
        "Has this company been free of any legal disputes or employee complaints regarding denied benefits or hidden healthcare fees over the last three years?",
    ],
    "health_and_safety": [
        "Does the company fully pay for and maintain required personal protective equipment at no cost to the employees?",
        "Is this facility currently certified under ISO 45001 or audited by an independent, accredited third party for occupational health and safety?",
        "Does the company teach laborers hazard recognition, fire prevention, and emergency protocols?",
    ],
    "association": [
        "Does the company allow employees to freely organize, join, or form labor unions without interference?",
        "Does the company provide protection for employees who organize, join a union, raise labor concerns, or participate in collective bargaining?",
    ],
    "grievances": [
        "Does the company have formal, low-barrier grievance policies in place for their workers?",
        "Does the company appropriately investigate and address grievances?",
    ],
    "working_hours_and_job_security": [
        "Does the company have defined maximum working hours that align with applicable labor standards and regulations?",
        "Does the company provide employees with fair, transparent, and clearly communicated employment contracts?",
    ],
    "equality_and_harassment": [
        "Does the company ensure equal treatment and prevent discrimination in the workplace?",
        "Does the company have policies and practices to prevent workplace harassment that are independently verified by a third party?",
    ],
    "transparency": [
        "Does the company publish annual reports, vendor lists, and sourcing profiles detailing labor practices, safety measures, and identified gaps under frameworks like the Fair Labor Association or the Ethical Trading Initiative?",
        "Does the company allow independent auditors to conduct scheduled and unannounced site inspections to verify safe working conditions, fair wages, and reasonable hours?",
        "Does the company adhere to statutory mandates such as the California Transparency in Supply Chains Act or the U.S. Uyghur Forced Labor Prevention Act?",
    ],
}


NON_ANIMAL_PRODUCT_RUBRIC: dict[str, float] = {
    "animal_testing": 0.30,
    "animal_derived_materials": 0.30,
    # The PDF's "3S0%" is interpreted as 30% so all weights total 100%.
    "animal_treatment": 0.30,
    "supplier_accountability": 0.10,
}

NON_ANIMAL_PRODUCT_QUESTIONS: dict[str, list[str]] = {
    "animal_testing": [
        "Does the company prohibit conducting animal tests in every market on finished products, formulations, and ingredients?",
        "Does its animal-testing prohibition cover ingredient suppliers and third-party manufacturers for the products they supply to the company?",
        "Does the company prohibit commissioning animal tests on finished products, formulations, and ingredients?",
        "Does the company prohibit funding animal tests?",
        "Does the company monitor compliance with its animal-testing policy and require corrective action when breaches occur?",
    ],
    "animal_derived_materials": [
        "Are all the company's products free of animal-derived ingredients and materials, including processing aids?",
        "Does the company publish measurable targets for replacing animal-derived ingredients and materials with animal-free alternatives?",
        "Does the company report measurable progress toward its animal-material replacement targets?",
    ],
    "animal_treatment": [
        "Does the company require suppliers of animal-derived ingredients or materials to meet species-appropriate welfare standards (including pain prevention, slaughter, transportation) covering nutrition, shelter, health, and natural behavior?",
        "Do third-party organizations verify that such welfare standards for animal-derived ingredients are upheld?",
        "Does the company monitor compliance with its animal welfare policies and require corrective action when breaches occur?",
    ],
    "supplier_accountability": [
        "Does the company trace animal-derived ingredients and materials to farms or other primary sources?",
    ],
}

# These lists follow the question order in NON_ANIMAL_PRODUCT_QUESTIONS.
NON_ANIMAL_PRODUCT_QUESTION_WEIGHTS: dict[str, list[float]] = {
    "animal_testing": [0.20, 0.20, 0.20, 0.20, 0.20],
    "animal_derived_materials": [0.50, 0.25, 0.25],
    "animal_treatment": [0.50, 0.25, 0.25],
    "supplier_accountability": [1.0],
}


ANIMAL_PRODUCT_RUBRIC: dict[str, float] = {
    "living_conditions": 0.40,
    "procedures": 0.15,
    "transport": 0.10,
    "slaughter": 0.35,
}

ANIMAL_PRODUCT_QUESTIONS: dict[str, list[str]] = {
    "living_conditions": [
        "Does the company and its facilities provide animals with ample space to move and rest?",
        "Does the company and its facilities provide animals an environment where they can engage in natural behaviors?",
        "Do farms prevent and address harmful aggression between animals?",
        "Do the company's employees refrain from physically abusing the animals?",
        "Are animal injuries and illnesses appropriately addressed by the company and its facilities?",
        "Does the company and its facilities provide animals with adequate, appropriate food and clean drinking water?",
        "Does the company and its facilities avoid inhumane breeding practices that inflict harm on animals?",
        "Does the company and its facilities maintain a clean environment (in terms of air quality, waste, and etc) for their farmed animals?",
    ],
    "procedures": [
        "Does the company and its facilities avoid unnecessary mutilation procedures on animals?",
        "Does the company and its facilities require anesthesia or pain relief for mutilation practices?",
    ],
    "transport": [
        "Are the animal transport times minimized and regulated by the company, following applicable standards set by the World Organization for Animal Health or the International Air Transport Association?",
        "Are the transported animals protected from exposure to extreme weather?",
        "Do the transportation systems prohibit animal overcrowding?",
    ],
    "slaughter": [
        "Are the animals slaughtered by the company and its facilities effectively stunned and unconscious before slaughter, and until death?",
        "Are the company's slaughtering practices Certified Humane, or follow similarly rigorous rules?",
    ],
}

ANIMAL_PRODUCT_QUESTION_WEIGHTS: dict[str, list[float]] = {
    "living_conditions": [0.125] * 8,
    "procedures": [0.50, 0.50],
    "transport": [1 / 3, 1 / 3, 1 / 3],
    "slaughter": [0.50, 0.50],
}


# Retain the existing names for scripts that use the non-animal rubric.
# API requests still select animal_products or non_animal_products explicitly.
ANIMAL_WELFARE_RUBRIC = NON_ANIMAL_PRODUCT_RUBRIC
ANIMAL_WELFARE_QUESTIONS = NON_ANIMAL_PRODUCT_QUESTIONS
ANIMAL_WELFARE_QUESTION_WEIGHTS = NON_ANIMAL_PRODUCT_QUESTION_WEIGHTS
