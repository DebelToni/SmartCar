import { useState, useEffect } from 'react';

// Define user profile interface
interface UserProfile {
  id: string;
  name: string;
  email: string;
  age?: number;
  address?: {
    street: string;
    city: string;
    zipCode: string;
  };
  preferences?: {
    newsletter: boolean;
    notifications: boolean;
  };
}

// Validation rules
const validateEmail = (email: string): boolean => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

const validateAge = (age?: number): boolean => {
  if (age === undefined) return true; // Optional field
  return age >= 0 && age <= 120;
};

const validateAddress = (address?: UserProfile['address']): boolean => {
  if (!address) return true;
  const { street, city, zipCode } = address;
  return (
    street.trim().length > 0 &&
    city.trim().length > 0 &&
    /^[0-9]{5}(-[0-9]{4})?$/.test(zipCode)
  );
};

// Simulate async fetch for user data
const fetchUserProfile = async (userId: string): Promise<UserProfile> => {
  // Simulated delay
  await new Promise((resolve) => setTimeout(resolve, 500));
  // Mock data
  return {
    id: userId,
    name: 'John Doe',
    email: 'john.doe@example.com',
    age: 30,
    address: {
      street: '123 Main St',
      city: 'Anytown',
      zipCode: '12345'
    },
    preferences: {
      newsletter: true,
      notifications: false
    }
  };
};

// Main React component
function UserProfileManager({ userId }: { userId: string }) {
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [validationErrors, setValidationErrors] = useState<{[key: string]: string}>({});

  // Fetch user data on mount or userId change
  useEffect(() => {
    let isMounted = true;
    setLoading(true);
    fetchUserProfile(userId)
      .then((data) => {
        if (isMounted) {
          setProfile(data);
          setLoading(false);
          setError(null);
        }
      })
      .catch((err) => {
        if (isMounted) {
          setError('Failed to fetch user data');
          setLoading(false);
        }
      });
    return () => {
      isMounted = false;
    };
  }, [userId]);

  // Handle input changes
  const handleChange = (field: keyof UserProfile, value: any) => {
    if (!profile) return;
    setProfile({ ...profile, [field]: value });
  };

  const handleNestedChange = (
    nestedField: keyof UserProfile['address'],
    value: string
  ) => {
    if (!profile || !profile.address) return;
    setProfile({
      ...profile,
      address: { ...profile.address, [nestedField]: value }
    });
  };

  // Validate entire profile
  const validateProfile = (): boolean => {
    if (!profile) return false;
    const errors: {[key: string]: string} = {};

    if (!profile.name || profile.name.trim().length === 0) {
      errors['name']'] = 'Name is required.';
    }
    if (!validateEmail(profile.email)) {
      errors['email']'] = 'Invalid email address.';
    }
    if (!validateAge(profile.age)) {
      errors['age']'] = 'Age must be between 0 and 120.';
    }
    if (!validateAddress(profile.address)) {
      errors['address']'] = 'Invalid address details.';
    }

    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleSave = () => {
    if (validateProfile()) {
      // Save logic here (e.g., API call)
      alert('Profile is valid and saved.');
    } else {
      alert('Please fix validation errors before saving.');
    }
  };

  if (loading) {
    return <div>Loading user profile...</div>;
  }

  if (error) {
    return <div>Error: {error}</div>;
  }

  if (!profile) {
    return <div>No profile data available.</div>;
  }

  return (
    <div>
      <h2>User Profile Management</h2>
      <div>
        <label>Name:</label>
        <input
          type="text"
          value={profile.name}
          onChange={(e) => handleChange('name', e.target.value)}
        />
        {validationErrors['name']']} && <span style={{color: 'red'}}>{validationErrors['name']']}</span>}
      </div>
      <div>
        <label>Email:</label>
        <input
          type="email"
          value={profile.email}
          onChange={(e) => handleChange('email', e.target.value)}
        />
        {validationErrors['email']']} && <span style={{color: 'red'}}>{validationErrors['email']']}</span>}
      </div>
      <div>
        <label>Age:</label>
        <input
          type="number"
          value={profile.age ?? ''}
          onChange={(e) => handleChange('age', parseInt(e.target.value, 10))}
        />
        {validationErrors['age']']} && <span style={{color: 'red'}}>{validationErrors['age']']}</span>}
      </div>
      <h3>Address</h3>
      <div>
        <label>Street:</label>
        <input
          type="text"
          value={profile.address?.street ?? ''}
          onChange={(e) => handleNestedChange('street', e.target.value)}
        />
      </div>
      <div>
        <label>City:</label>
        <input
          type="text"
          value={profile.address?.city ?? ''}
          onChange={(e) => handleNestedChange('city', e.target.value)}
        />
      </div>
      <div>
        <label>Zip Code:</label>
        <input
          type="text"
          value={profile.address?.zipCode ?? ''}
          onChange={(e) => handleNestedChange('zipCode', e.target.value)}
        />
        {validationErrors['address']']} && <span style={{color: 'red'}}>{validationErrors['address']']}</span>}
      </div>
      <h3>Preferences</h3>
      <div>
        <label>
          <input
            type="checkbox"
            checked={profile.preferences?.newsletter ?? false}
            onChange={(e) => {
              if (!profile.preferences) return;
              setProfile({
                ...profile,
                preferences: {
                  ...profile.preferences,
                  newsletter: e.target.checked
                }
              });
            }}
          />
          Subscribe to newsletter
        </label>
      </div>
      <div>
        <label>
          <input
            type="checkbox"
            checked={profile.preferences?.notifications ?? false}
            onChange={(e) => {
              if (!profile.preferences) return;
              setProfile({
                ...profile,
                preferences: {
                  ...profile.preferences,
                  notifications: e.target.checked
                }
              });
            }}
          />
          Enable notifications
        </label>
      </div>
      <button onClick={handleSave}>Save Profile</button>
    </div>
  );
}

export default UserProfileManager;