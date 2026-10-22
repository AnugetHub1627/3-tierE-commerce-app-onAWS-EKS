
3-Tier E-Commerce Application Deployment on AWS EKS
The application uses a decoupled 3-Tier Architecture designed for high-availability cloud deployment:
1. Presentation Tier (Frontend): A localized React user interface compiled into optimized production bundles and served via a high-performance Nginx web server.
2. Application Tier (Backend): A Node.js REST API service that handles business logic, exposes endpoint routers, and orchestrates query channels.
3. Data Tier (Database): A stateful MySQL relational database engine that houses inventory schemas, catalog tables, and records.

🛠️ Project Implementation Lifecycle
Phase 1: Local Containerization, Orchestration & Network Verification
In this foundational phase, the entire multi-tier stack was containerized, configured, and locally validated on Docker Desktop to achieve absolute environment parity before 
cloud migration.
Key Tasks Completed:
• Docker Multi-Container Orchestration: Integrated distinct Dockerfiles for the React frontend and Node.js backend services, orchestrating the uniform initialization using 
a root-level docker-compose.yml manifest.
• YAML Compiler Troubleshooting: Isolated and resolved severe go-yaml compiler exceptions and scanner syntax faults (could not find expected ':') caused by formatting rules 
and hidden trailing character streams.
• React Production Build Compilation: Re-architected missing entry-point dependencies (public/index.html and src/index.js) to allow the react-scripts build compiler to 
generate optimized client layers without throwing minifier locks or EOF crashes.
• Host Socket Conflict Resolution: Debugged container daemon deployment blockages by neutralizing active local OS port bindings on port 3306, freeing up host system resources
for the containerized database engine.
• Cross-Tier Networking & Service Discovery: Configured private bridge networks mapping cross-container endpoints through localized DNS names (mysql-db), cleanly isolating 
database components while allowing direct backend access to frontend clients via port mappings (localhost:5000/api/products).
• Stateful Volume Binding: Configured local persistent volume mappings (db-data:/var/lib/mysql) to ensure data preservation across lifecycle restarts, completing a successful
end-to-end HTTP 200 system handshake.

Phase 2: Terraform Infrastructure Architecture

We refactored the infrastructure layout to align with production best practices for a cloud-isolated 3-tier application:
• Subnet Tag Correction: Fixed a critical EKS cluster name misconfiguration in the private subnets. Updated the network tags from public load balancers (elb) to internal load balancers (internal-elb) so AWS can accurately route microservice traffic.
• Database Isolation: Moved the database tier out of the EKS cluster and provisioned a fully managed AWS RDS MySQL Instance inside a dedicated, isolated database subnet group.
• Security Whitelisting: Designed an AWS Security Group handshake that locks down the RDS MySQL database, allowing inbound connections strictly from your EKS worker node security group on port 3306.
• Private Container Registries: Added Amazon ECR configuration blocks to dynamically create private hosting repositories for both the frontend and backend Docker images.
• Automated Outputs: Built an outputs.tf file to auto-print your live RDS database string and ECR image URLs to your terminal, eliminating manual lookup steps.

☸️ Phase 3: Kubernetes Application Tier Workflow

We designed the application manifest strategy to cleanly bridge your custom Node.js application to the newly isolated AWS infrastructure:
• Securing Database Credentials: Handled Kubernetes configuration standards by converting your plain text database password into a Base64-scrambled secret layout (db-secret.yaml).
• Environment-Driven Configurations: Refactored the backend-deployment.yaml file to pull its database host address from your dynamic Terraform outputs, while seamlessly injecting user credentials via the secure Kubernetes secrets engine.
• Unified Registry Addresses: Constructed the exact 12-digit ECR address URL structures (://amazonaws.com) needed by Kubernetes to fetch your custom code builds from your Mumbai data center.
• Public Entrypoint Binding: Configured the frontend-deployment.yaml with the proper AWS load balancer annotations so that deploying the file triggers AWS to generate an external Internet Load Balancer link to access your e-commerce store.

Errors I faced:
1. Error in provisioning Aws load balancer controller
   - Pods are created but went to LoopBackOff state
     Reason : The AWS Load Balancer Controller is trying to automatically figure out its VPC ID by making a request to the AWS Instance Metadata Service (IMDSv2) on the worker node. However, your EKS worker nodes are blocking this request (returning a 401 Unauthorized error), or IMDSv2 hop limits are preventing the container from reaching it.
   - Solution : explicitly pass vpc_id into Helm configuration block so the controller doesn't have to guess or query the metadata service.
   - How : added follows block in my helm configuration in terraform main.tf
     set {
    name  = "vpcId"
    value = aws_vpc.your_vpc.id  # Replace with your actual Terraform VPC resource or variable
  }
  - finally AWS load balancer controller created.

2. Error in building and pushing image to AWS ECR
   Reason : GitHub Actions runner cannot find a folder named backend in the root directory of my repository. because my backend in not in root directory. It is in subfolder.
   Solution : added correct path and issue resolved.

3. ERROR: failed to build: failed to solve: process "/bin/sh -c npm run build" did not complete successfully: exit code: 1
   Reason : The build tool inside frontend Docker container (likely Create React App, Vite, or Next.js) is encountering these deprecation warnings and treating them as         fatal compilation errors because it detects it is running inside a CI environment (GitHub Actions).
   Solution : Can tell the Node build process to ignore warnings and treat them as non-blocking by injecting ENV CI=false directly into frontend Dockerfile.

       
     
   
