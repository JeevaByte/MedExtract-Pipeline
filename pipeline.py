"""Medical data extraction pipeline."""
import re


class MedExtractPipeline:
    """Pipeline for extracting medical information from text."""
    
    def __init__(self):
        """Initialize the pipeline."""
        self.medical_terms = [
            'diagnosis', 'symptom', 'treatment', 'medication',
            'patient', 'doctor', 'hospital', 'clinic'
        ]
    
    def extract_entities(self, text):
        """Extract medical entities from text."""
        if not text:
            return []
        
        entities = []
        text_lower = text.lower()
        
        for term in self.medical_terms:
            if term in text_lower:
                # Find all occurrences of the term
                pattern = re.compile(r'\b' + re.escape(term) + r'\b', re.IGNORECASE)
                matches = pattern.finditer(text)
                for match in matches:
                    entities.append({
                        'term': match.group(),
                        'start': match.start(),
                        'end': match.end(),
                        'type': 'medical_term'
                    })
        
        return entities
    
    def extract_dates(self, text):
        """Extract dates from text."""
        if not text:
            return []
        
        # Simple date pattern (MM/DD/YYYY or DD-MM-YYYY)
        date_pattern = r'\b\d{1,2}[-/]\d{1,2}[-/]\d{2,4}\b'
        dates = []
        
        for match in re.finditer(date_pattern, text):
            dates.append({
                'date': match.group(),
                'start': match.start(),
                'end': match.end()
            })
        
        return dates
    
    def process(self, text):
        """Process text and extract all medical information."""
        return {
            'entities': self.extract_entities(text),
            'dates': self.extract_dates(text),
            'text_length': len(text) if text else 0
        }
