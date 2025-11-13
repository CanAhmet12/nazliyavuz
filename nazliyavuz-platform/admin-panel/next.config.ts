import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Remove standalone mode to ensure static files are properly served
  // Static files should be accessible from .next/static
};

export default nextConfig;
