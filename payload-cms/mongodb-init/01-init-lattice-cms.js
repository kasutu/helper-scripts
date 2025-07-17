// MongoDB initialization script for lattice-cms database
// This script runs when the MongoDB container starts for the first time

// Create the lattice-cms database
db = db.getSiblingDB('lattice-cms');

// Create collections that Payload CMS typically uses
db.createCollection('users');
db.createCollection('payload-preferences');
db.createCollection('payload-migrations');

// Create indexes for better performance
db.users.createIndex({ "email": 1 }, { unique: true });
db.users.createIndex({ "createdAt": 1 });
db.users.createIndex({ "updatedAt": 1 });

// Create a basic admin user (optional - you can also create via Payload CMS)
// Note: Password should be changed immediately after first login
/*
db.users.insertOne({
  email: "admin@lattice-cms.com",
  password: "$2b$12$hashed_password_here", // This should be properly hashed
  role: "admin",
  createdAt: new Date(),
  updatedAt: new Date()
});
*/

print('✅ lattice-cms database initialized successfully');
print('📄 Collections created: users, payload-preferences, payload-migrations');
print('🔍 Indexes created for performance optimization');
print('⚠️  Remember to create your admin user through Payload CMS admin panel');
