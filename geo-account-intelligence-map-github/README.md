# Geo Account Intelligence Map

A Salesforce dashboard that puts accounts and opportunities on a map, so sales teams can see **where their accounts are, where the pipeline is, and what's happening around them**.

## What is this?

Salesforce has a lot of useful account and opportunity data, but most of it is viewed through lists and tables.

I wanted to build a simple way to look at that same information geographically.

With the Geo Account Intelligence Map, a sales user can open a map and quickly see:

- Where their accounts are located
- Which accounts have open opportunities
- Where the pipeline is concentrated
- What accounts are near a particular location
- Which nearby accounts may need attention

The goal is to make geographic account planning easier without leaving Salesforce.

## What can you do with it?

### 🗺️ See Accounts on a Map

Accounts are displayed based on their geographic location, giving sales teams a quick visual view of their territory.

### 📍 Find Accounts Nearby

Select a location and radius to find accounts within a specific area.

This can be useful when planning customer visits or looking for additional accounts around an existing customer.

### 💰 See Pipeline Around You

Opportunities are connected to the accounts on the map, making it easier to understand where the current pipeline is located.

### 🔎 Explore Account Details

Select an account to see relevant account and opportunity information without having to search through Salesforce lists.

### 🎯 Spot Sales Opportunities

The map makes it easier to notice areas with multiple accounts, active opportunities, or potential sales activity.

## Example Use Cases

A sales rep could use the map to answer questions like:

> "I have a meeting with a customer tomorrow. What other accounts are nearby?"

> "Where is most of my current pipeline located?"

> "Which accounts around this area have open opportunities?"

> "Are there other accounts I should be visiting while I'm in this territory?"

## How it is built

This project is built using Salesforce and a few familiar web technologies:

- **Lightning Web Components (LWC)** — dashboard and user interface
- **Apex** — retrieving and preparing Salesforce data
- **SOQL** — querying Accounts and Opportunities
- **Leaflet.js** — interactive map
- **Salesforce Static Resources** — hosting the Leaflet library
- **JavaScript / HTML / CSS** — map interactions and UI

## How it works

The basic flow is:


Salesforce Accounts & Opportunities
                ↓
              Apex
                ↓
          Lightning Web Component
                ↓
        Geographic calculations
                ↓
           Leaflet Map